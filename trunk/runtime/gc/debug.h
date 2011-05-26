/* Copyright (C) 1999-2007 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a BSD-style license.
 * See the file MLton-LICENSE for details.
 */

#ifndef DEBUG
#define DEBUG TRUE
#endif


enum {
  DEBUG_ARRAY = TRUE,
  DEBUG_CALL_STACK = TRUE,
  DEBUG_CARD_MARKING = TRUE,
  DEBUG_DETAILED = TRUE,
  DEBUG_DFS_MARK = TRUE,
  DEBUG_ENTER_LEAVE = TRUE,
  DEBUG_GENERATIONAL = TRUE,
  DEBUG_INT_INF = TRUE,
  DEBUG_INT_INF_DETAILED = TRUE,
  DEBUG_MARK_COMPACT = TRUE,
  DEBUG_MEM = TRUE,
  DEBUG_OBJPTR = TRUE,
  DEBUG_PROFILE = TRUE,
  DEBUG_RESIZING = TRUE,
  DEBUG_SHARE = TRUE,
  DEBUG_SIGNALS = TRUE,
  DEBUG_SIZE = TRUE,
  DEBUG_SOURCES = TRUE,
  DEBUG_SPLICE = TRUE,
  DEBUG_STACKS = TRUE,
  DEBUG_THREADS = TRUE,
  DEBUG_WEAK = TRUE,
  DEBUG_WORLD = TRUE,
  FORCE_GENERATIONAL = FALSE,
  FORCE_MARK_COMPACT = FALSE,
};
