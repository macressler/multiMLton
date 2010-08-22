(* Copyright (C) 2004-2008 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under a BSD-style license.
 * See the file MLton-LICENSE for details.
 *)

structure List =
   struct
      fun foreach (l, f) = List.app f l
      fun map (l, f) = List.map f l
      val tabulate = List.tabulate
   end

val int =
   ["Int", "IntInf", "LargeInt", "FixedInt", "Position"]
   @ List.map (List.tabulate (31, fn i => i + 2) @ [64],
               fn i => concat ["Int", Int.toString i])

val real = ["Real", "Real32", "Real64", "LargeReal"]

val word =
   ["Word", "LargeWord", "SysWord"]
   @ List.map (List.tabulate (32, fn i => i + 1) @ [64],
               fn i => concat ["Word", Int.toString i])

val text = ["Char", "WideChar", "String", "WideString"]

(* Order matters here in the appends, since the first element will be the
 * default.
 *)
val num = int @ word @ real
val numtext = num @ text
val realint = int @ real
val wordint = int @ word

val binary = "'a * 'a -> 'a"
val compare = "'a * 'a -> bool"
val unary = "'a -> 'a"

val () = print "(* This file is automatically generated.  Do not edit. *)\n"

val () =
   List.foreach
   ([(2, "~", unary, num),
     (2, "+", binary, num),
     (2, "-", binary, num),
     (2, "*", binary, num),
     (4, "/", binary, real),
     (3, "div", binary, wordint),
     (3, "mod", binary, wordint),
     (3, "abs", unary, realint),
     (1, "<", compare, numtext),
     (1, "<=", compare, numtext),
     (1, ">", compare, numtext),
     (1, ">=", compare, numtext)],
    fn (prec, f, ty, class) =>
    (print (concat ["\n_overload ", Int.toString prec, " ", f, " : ", ty, "\n"])
     ; (case class of
           [] => ()
         | c :: class =>
              (print (concat ["as  ", c, ".", f, "\n"])
               ; List.foreach (class, fn c =>
                               print (concat ["and ", c, ".", f, "\n"]))))))
