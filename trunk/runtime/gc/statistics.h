/* Copyright (C) 1999-2008 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a BSD-style license.
 * See the file MLton-LICENSE for details.
 */

#if (defined (MLTON_GC_INTERNAL_TYPES))

enum {
  SYNC_NONE = 0,
  SYNC_OLD_GEN_ARRAY,
  SYNC_NEW_GEN_ARRAY,
  SYNC_STACK,
  SYNC_HEAP,
  SYNC_LIFT,
  SYNC_FORCE,
  SYNC_PACK,
  SYNC_SAVE_WORLD,
  SYNC_SIGNALS,
};

enum {
  SUMMARY_NONE = 0,
  SUMMARY_CUMULATIVE,
  SUMMARY_INDIVIDUAL,
};

struct GC_cumulativeStatistics {
  uintmax_t bytesAllocated;
  uintmax_t bytesCopied;
  uintmax_t bytesCopiedMinor;
  uintmax_t bytesHashConsed;
  uintmax_t bytesMarkCompacted;
  uintmax_t bytesScannedMinor;
  uintmax_t bytesLifted;

  size_t maxBytesLive;
  size_t maxHeapSize;
  uintmax_t maxPauseTime;
  size_t maxStackSize;

  uintmax_t numCardsMarked; /* Number of marked cards seen during minor GCs. */

  uintmax_t numGCs;
  uintmax_t numCopyingGCs;
  uintmax_t numHashConsGCs;
  uintmax_t numMarkCompactGCs;
  uintmax_t numMinorGCs;
  uintmax_t numThreadsCreated;

  struct timeval ru_gc; /* total resource usage in gc. */
  struct rusage ru_gcCopying; /* resource usage in major copying gcs. */
  struct rusage ru_gcMarkCompact; /* resource usage in major mark-compact gcs. */
  struct rusage ru_gcMinor; /* resource usage in minor copying gcs. */

  uintmax_t numLimitChecks;
  uintmax_t bytesFilled; /* i.e. unused gaps */
  size_t maxBytesLiveSinceReset;
  struct rusage ru_thread; /* total resource for thread operations */

  /* use wall clock instead of rusage */
  struct timeval tv_rt; /* total time "inside" runtime (not incl. synch.) */
  struct timeval tv_sync; /* time waiting to synchronize in runtime */

  uintmax_t syncForOldGenArray;
  uintmax_t syncForNewGenArray;
  uintmax_t syncForStack;
  uintmax_t syncForHeap;
  uintmax_t syncForLift;
  uintmax_t syncForce;
  uintmax_t syncMisc;

  uintmax_t numPreemptWB; /* # calls to addToPreemptOnWBA -- actual # threads preempted on write barrier */
  uintmax_t numMoveWB; /* # calls to addToMoveOnWBA -- ideal # threads that should have been preempted on write barrier */
  uintmax_t numReadyWB; /* # ready threads on scheduler while a thread is preempted on write barrier */

};

struct GC_lastMajorStatistics {
  size_t bytesHashConsed;
  size_t bytesLive; /* Number of bytes live at most recent major GC. */
  GC_majorKind kind;
  uintmax_t numMinorGCs;
};

#endif /* (defined (MLTON_GC_INTERNAL_TYPES)) */


#if (defined (MLTON_GC_INTERNAL_FUNCS))

static inline void incSync (GC_state s);

#endif /* (defined (MLTON_GC_INTERNAL_FUNCS)) */
