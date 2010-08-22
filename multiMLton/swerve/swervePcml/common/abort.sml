(*
Original Code - Copyright (c) 2001 Anthony L Shipman
MLton Port Modifications - Copyright (c) Ray Racine

Permission is granted to anyone to use this version of the software
for any purpose, including commercial applications, and to alter it and
redistribute it freely, subject to the following restrictions:

    1. Redistributions in source code must retain the above copyright
    notice, this list of conditions, and the following disclaimer.

    2. The origin of this software must not be misrepresented; you must
    not claim that you wrote the original software. If you use this
    software in a product, an acknowledgment in the product documentation
    would be appreciated but is not required.

    3. If any files are modified, you must cause the modified files to
    carry prominent notices stating that you changed the files and the
    date of any change.

Disclaimer

    THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESSED OR IMPLIED
    WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
    OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY DIRECT,
    INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
    HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
    STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
    IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.

Modification History
====================
Ray Racine 6/3/2005 - MLton Port and idiomatic fixups.
*)


structure Abort: ABORT =
struct

    structure TF = TextFrag
    structure L = MLton.PCML.MutexLock
    structure T = MLton.Thread
    datatype t = Abort of unit MLton.PCML.SyncVar.ivar

    (* This maintains a well-balance tree to map from future times to aborts.
     * We will only retain weak references to the aborts so that they drop
     * out of the map when the client is no longer interested in them.

     * Since the key is fixed at type int I use as a measure of time
     * the number of seconds since the server started. This should fit
     * into 30 bits! *)
    structure M = IntRedBlackMap
    structure Map =
    struct

      type 'a map = ('a M.map * L.mutexlock)

      fun doit f lock =
      let
        (* val _ = L.getLock lock *)
        val res = f ()
        (* val _ = L.releaseLock lock *)
      in
        res
      end

      fun empty () = (M.empty, L.initLock ())
      fun find ((m, lock), x) = doit (fn () => M.find (m,x)) lock
      fun insert ((m, lock), a, b) = doit (fn () => (M.insert(m,a,b), lock)) lock
      fun numItems ((m, lock)) = doit (fn () => M.numItems(m)) lock
      fun foldli f (a,b) (m2, lock) = doit (fn () => (M.foldli f M.empty m2, lock)) lock
    end

    datatype Request =
	    Add of int * t	    	    (* ( timeout, force ) -> abort *)

    datatype State = State of
	     { time: int,	       	    (* seconds since startup *)
    	       live: ( t list ) Map.map     (* waiting to expire *) }

    fun server ch () =
	let val start = Time.now()

        val _ = Debug.debug' "Abort.server"
	    fun toTime secs = Time.fromSeconds ( LargeInt.fromInt secs )
	    fun trunc  time = Int.fromLarge ( Time.toSeconds time )

	    fun loop ( state as State { time, ... } ) =
		let fun request (Add (delay, abort)) = add delay abort state

		    (* If the timing drifts off it won't hurt if this
		     * event is for a time in the past. It will be immediately
		     * enabled. *)
		    val time_evt = MLton.PCML.atTimeEvt(Time.+(start, toTime(time+1)))

		    val new_state = MLton.PCML.select
					[
					  MLton.PCML.wrap ( time_evt,
		    				     (*MyProfile.timeIt "abort expire"*) ( expire state ) ),
                      MLton.PCML.wrap ( MLton.PCML.recvEvt ch,
						     MyProfile.timeIt "abort request" request ) ]

		in
		    loop new_state
		end


	and add delay abort (state as State {time, live}) =
	let
	    (* Find out the end-time in seconds relative to
	     * the start time of the server, rounded to the
	     * nearest second. *)

	    val now   = Time.now()
	    val since = Time.-(now, start)
	    val ends  = trunc ( Time.+ ( Time.+ ( since, toTime delay ),
	    				 Time.fromMilliseconds 250 ) )

	    val _ = Log.testInform Globals.TestTimeout Log.Debug
		    ( fn() => TF.concat [ "Abort add delay=",
					  Int.toString delay,
		    			  " now= ", Time.fmt 6 now,
					  " ends=", Int.toString ends ] )

	    (* The insert operation will either insert or replace. *)
	    fun add_abort() =
	    (
		case Map.find(live, ends) of
		  NONE =>
		    let
			val new_live = Map.insert(live, ends, [abort])
		    in
			State {time=time, live=new_live}
		    end

		| SOME ab_list =>
		    let
			val new_live = Map.insert(live, ends, abort::ab_list)
		    in
			State {time=time, live=new_live}
		    end
	    )
	in
	    add_abort()
	end


	(* This scans all of the live entries looking for aborts to
	 * expire. *)
	and expire (state as State {time, live}) () =
	let
	    (*	Find out what the time really is. *)
	    val count = trunc(Time.-(Time.now(), start))
	    fun check_entry (at_time, ab_list, new_live) =
	    ( if count >= at_time
	      then  (Log.testInform Globals.TestTimeout Log.Debug
				    ( fn () => TF.concat [ "Abort expiring, count=",
						       Int.toString count,
						       " live size=",
						       Int.toString ( Map.numItems live ) ] );
		     (* Remove the entry and set all its aborts. *)
               Debug.debug' "Abort.check_entry(2)";
		     app set_ab ab_list;
		     new_live )
	      else (* Put the entry back into the map. *)
		  M.insert(new_live, at_time, ab_list) )


	    and set_ab (Abort ivar) = (MLton.PCML.SyncVar.iPut(ivar, ()))
		handle _ => ()

	    val new_live = Map.foldli check_entry (Map.empty ()) live
        val _ = Debug.debug' "Abort.expire(3)"
	in
	    State {time=count, live=new_live}
	end

	in
	    loop (State {time = 0, live = Map.empty ()})
	end



    structure Mgr = Singleton( type input    = Request MLton.PCML.chan
                               val  newInput = MLton.PCML.channel
                               val  object   = server )

    fun create delay =
    let	fun run() =
	let val abort = Abort (MLton.PCML.SyncVar.iVar())
	in
	    MLton.PCML.send(Mgr.get(), Add(delay, abort));
	    abort
	end
    in
	MyProfile.timeIt "abort create" run ()
    end

    fun evt     ( Abort ivar ) = MLton.PCML.SyncVar.iGetEvt ivar
    fun aborted ( Abort ivar ) = isSome ( MLton.PCML.SyncVar.iGetPoll ivar )

    fun force   ( Abort ivar ) = MLton.PCML.SyncVar.iPut ( ivar, () )
    	handle _ => ()

    fun never() = Abort ( MLton.PCML.SyncVar.iVar () )

end
