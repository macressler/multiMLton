structure Main : MAIN =
struct

  open Critical

  structure S = Scheduler
  structure SQ = SchedulerQueues
  structure SH = SchedulerHooks
  structure TO = Timeout
  structure TID = ThreadID
  structure MT = MLtonThread
  structure PT = ProtoThread

  structure Assert = LocalAssert(val assert = false)
  structure Debug = LocalDebug(val debug = false)

  fun debug msg = Debug.sayDebug ([atomicMsg, TID.tidMsg], msg)
  fun debug' msg = debug (fn () => msg()^" : "^Int.toString(PacmlFFI.processorNumber()))



  (* Enabling preemption for processor 0
   * For other processors, preemprtion is enabled when they are scheduled
   *)
  val _ = PacmlFFI.enablePreemption ()
  val numberOfProcessors = PacmlFFI.numberOfProcessors

  local
    structure Signal = MLtonSignal
    structure Itimer = MLtonItimer

    fun getAlrmHandler () =
      Signal.getHandler Posix.Signal.alrm
    fun setAlrmHandler h =
      Signal.setHandler (Posix.Signal.alrm, h)

    fun setItimer t =
      Itimer.set (Itimer.Real, {value = t, interval = t})
  in
    fun prepareAlrmHandler tq =
      let
          val origAlrmHandler = getAlrmHandler ()
          val tq =
            case tq of
                SOME tq => tq
              | NONE => Time.fromMilliseconds 20
      in
          (fn alrmHandler =>
          (setAlrmHandler (Signal.Handler.handler (S.unwrap alrmHandler Thread.reifyHostFromParasite))
            ; setItimer tq),
          fn () =>
          (setItimer Time.zeroTime
            ; setAlrmHandler origAlrmHandler))
      end
  end

  fun alrmHandler thrd =
    let
      val () = Assert.assertAtomic' ("RunCML.alrmHandler", SOME 1)
      val () = debug' (fn () => "alrmHandler(1)") (* Atomic 1 *)
      val () = S.preempt thrd
      val () = TO.preemptTime ()
      val _ = TO.preempt ()
      val nextThrd = S.next()
      val () = debug' (fn () => "alrmHandler(2)")
    in
      nextThrd
    end

  fun thread_main () =
  let
    val _ = MLtonProfile.init ()
    val _ = PacmlFFI.disablePreemption ()

    fun wait () =
      if !Config.isRunning then
        ()
      else
        (PacmlFFI.maybeWaitForGC ();
         PacmlFFI.wait ();
         wait ())

    val _ = wait ()

    fun loop procNum =
    let
      val _ = PacmlFFI.maybeWaitForGC ()
    in
      case doAtomic (fn () => SQ.dequeHost (RepTypes.PRI)) of
           NONE => (PacmlFFI.wait (); loop procNum)
         | SOME (t) =>
             let
               val _ = if !Config.isRunning then ()
                       else (loop procNum)
               val _ = atomicBegin ()
               val _ = PacmlFFI.enablePreemption ()
               (* val (installAlrmHandler, _) = prepareAlrmHandler NONE
               val _ = installAlrmHandler alrmHandler *)
             in
               S.atomicSwitch (fn _ => t)
             end
    end
  in
    loop (PacmlFFI.processorNumber ())
  end

  val () = (_export "Parallel_run": (unit -> unit) -> unit;) thread_main


  fun pause () =
  let
    fun tightLoop2 n =
      if n=0 then ()
      else tightLoop2 (n-1)

    fun tightLoop n = (* tightLoop (1000) ~= 1ms on 1.8Ghz core *)
      if n=0 then ()
      else (tightLoop2 300; tightLoop (n-1))
  in
    tightLoop (Config.pauseToken)
  end


  fun pauseHook (iter, to) =
    let
      val to = if iter=0 then TO.preempt () else to
      val iter = case to of
                    NONE => if (iter > Config.maxIter) then (PacmlFFI.wait (); iter-1) else iter
                  | _ => if (iter > Config.maxIter) then (TO.preemptTime (); ignore (TO.preempt ()); 0) else iter
      val () = if not (!Config.isRunning) then (atomicEnd ();ignore (SchedulerHooks.deathTrap())) else ()
    in
      S.nextWithCounter (iter + 1, to)
    end

  fun reset running =
      (S.reset running
      ; SH.reset ()
      ; TID.reset ()
      ; TO.reset ())


  val numIOThreads = PacmlFFI.numIOProcessors

  fun shutdown status =
    if (!Config.isRunning)
      then S.switch (fn _ => PT.getRunnableHost(PT.prepVal (!SH.shutdownHook, status)))
      else raise Fail "CML is not running"

  fun runtimeInit () =
  let
    val () = PacmlPrim.initRefUpdate (S.preemptOnWriteBarrier)
    val () = Primitive.MLton.parallelInit ()
  in
    ()
  end


  fun run (initialProc : unit -> unit) =
  let
    (* DO NOT REMOVE *)
    val _ = runtimeInit ()
    val status =
        S.switchToNext
        (fn thrd =>
        let
          fun lateInit () =
          let
            val () = Config.isRunning := true
            val () = debug' (fn () => "lateInit")
            (* Spawn the Non-blocking worker threads *)
            val _ = List.tabulate (numIOThreads * 5, fn _ => NonBlocking.mkNBThread ())
            val _ = List.tabulate (numIOThreads, fn i => PacmlFFI.wakeUp (PacmlFFI.numComputeProcessors + i, 1))
            (* val (installAlrmHandler, _) = prepareAlrmHandler NONE
            val _ = installAlrmHandler alrmHandler *)
          in
            ()
          end
          val () = debug' (fn () => concat ["numberOfProcessors = ", Int.toString (PacmlFFI.numberOfProcessors)])
          val () = debug' (fn () => concat ["numComputeProcessors = ", Int.toString (PacmlFFI.numComputeProcessors)])
          val () = debug' (fn () => concat ["numIOProcessors = ", Int.toString (PacmlFFI.numIOProcessors)])
          val () = reset true
          val () = debug' (fn () => "Main(-2)")
          val () = SH.shutdownHook := PT.prepend (thrd, fn arg => (atomicBegin (); arg))
          val () = debug' (fn () => "Main(-1)")
          val () = SH.pauseHook := pauseHook
          val () = debug' (fn () => "Main(0)")
          val () = ignore (Thread.spawn (fn ()=> (lateInit (); initialProc ())))
        in
            ()
        end)
      val () = reset false
      val () = Config.isRunning := false
      val () = atomicEnd ()
    in
      status
    end

end
