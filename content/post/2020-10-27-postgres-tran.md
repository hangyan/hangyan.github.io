---
title: "笔记: Postgresql里的事务实现"
date: 2020-10-27T15:33:02+08:00
draft: false
categories: [Database]
tags: [postgresql,notes]
---

虽然日常工作需要涉及到数据库的底层部分并不多，但Postgresql作为一个数据库实现的范本是很值得研究的。可以通过它的实现来探索很多通用的数据库设计以及系统设计的理念。本文主要关注于事物设计方面。

## MVCC
pg底层使用`MVCC`，修改数据时会直接创建新版本，而不是直接修改旧数据。这部分有一点需要注意的是在pg中，所有的语句都是在事物中执行的，不管是不是明确地用了`BEGIN/COMMIT`。

## Transactions, tuples, and snapshots
先看一下 Transaction 的主要数据结构:

```c
typedef struct PGXACT
{
    TransactionId xid;   /* id of top-level transaction currently being
                          * executed by this proc, if running and XID
                          * is assigned; else InvalidTransactionId */

    TransactionId xmin;  /* minimal running XID as it was when we were
                          * starting our xact, excluding LAZY VACUUM:
                          * vacuum must not remove tuples deleted by
                          * xid >= xmin ! */

    ...
} PGXACT;

```
事物以`xid`作为标识.pg针对它做了很多优化，仅在真正开始写数据的时候才分配xid,如果是只读的事物就完全不分配。
`xmin`表示当这个事物开始的时候仍然处在运行中的事物列表中最小的那个`xid`

表中的 `record`，pg中称之为`tuples`.下面是 tuples 相关的一些数据结构:
```c 
typedef struct HeapTupleData
{
    uint32          t_len;         /* length of *t_data */
    ItemPointerData t_self;        /* SelfItemPointer */
    Oid             t_tableOid;    /* table the tuple came from */
    HeapTupleHeader t_data;        /* -> tuple header and data */
} HeapTupleData;

/* referenced by HeapTupleData */
struct HeapTupleHeaderData
{
    HeapTupleFields t_heap;

    ...
}
/* referenced by HeapTupleHeaderData */
typedef struct HeapTupleFields
{
    TransactionId t_xmin;        /* inserting xact ID */
    TransactionId t_xmax;        /* deleting or locking xact ID */

    ...
} HeapTupleFields;

```
上面的 `HeapTupleFields` 里面也记录了如事物一样的`xmin`之类的字段。Tuples 通过这种方式也记录了与自身相关联的事物信息。xmin是tuple数据第一次对外可见，就是执行插入操作的事物。xmax是tuple数据最后一次对外可见的事物id,也就是指删除这个tuple的操作。下面的图示会更清楚些:

![](https://brandur.org/assets/images/postgres-atomicity/heap-tuple-visibility.svg)

最终，我们来看看 Snapshot 的数据结构:
```c 
typedef struct SnapshotData
{
    /*
     * The remaining fields are used only for MVCC snapshots, and are normally
     * just zeroes in special snapshots.  (But xmin and xmax are used
     * specially by HeapTupleSatisfiesDirty.)
     *
     * An MVCC snapshot can never see the effects of XIDs >= xmax. It can see
     * the effects of all older XIDs except those listed in the snapshot. xmin
     * is stored as an optimization to avoid needing to search the XID arrays
     * for most tuples.
     */
    TransactionId xmin;            /* all XID < xmin are visible to me */
    TransactionId xmax;            /* all XID >= xmax are invisible to me */

    /*
     * For normal MVCC snapshot this contains the all xact IDs that are in
     * progress, unless the snapshot was taken during recovery in which case
     * it's empty. For historic MVCC snapshots, the meaning is inverted, i.e.
     * it contains *committed* transactions between xmin and xmax.
     *
     * note: all ids in xip[] satisfy xmin <= xip[i] < xmax
     */
    TransactionId *xip;
    uint32        xcnt; /* # of xact ids in xip[] */

    ...
}
```
这里的 xmin 跟事物的 xmin 计算方法类似。当一个 snapshot 被创建的时候，xid是正在运行的事物的最小的xid.xid < xmin 的事物创建的tuples对于此 snapshot 都是可见的。

xmax等于最后提交的一个事物的xid+1.xid >= xmax 的事物所做的修改对于对于这个 snapshot 都是不可见的。
`xip` 是snapshot创建时所有正在运行的事物的id列表。一些比xmin大的xid可能在snapshot创建时已经commited,所以只靠xmin来判断也不靠谱。

![](https://brandur.org/assets/images/postgres-atomicity/snapshot-creation.svg)

## 事物处理
当一个事物开始执行语句时，会触发生成 snapshot 的操作:
```c 
static void
exec_simple_query(const char *query_string)
{
    ...

    /*
     * Set up a snapshot if parse analysis/planning will need one.
     */
    if (analyze_requires_snapshot(parsetree))
    {
        PushActiveSnapshot(GetTransactionSnapshot());
        snapshot_set = true;
    }

    ...
}

Snapshot
GetSnapshotData(Snapshot snapshot)
{
    /* xmax is always latestCompletedXid + 1 */
    xmax = ShmemVariableCache->latestCompletedXid;
    Assert(TransactionIdIsNormal(xmax));
    TransactionIdAdvance(xmax);

    ...

    snapshot->xmax = xmax;
}

```

上面`GetSnapshotData` 里的代码设置了`xmax`的值。下面的片段设置了`xmin` 和 `xip`:
```c 
/*
 * Spin over procArray checking xid, xmin, and subxids.  The goal is
 * to gather all active xids, find the lowest xmin, and try to record
 * subxids.
 */
for (index = 0; index < numProcs; index++)
{
    volatile PGXACT *pgxact = &allPgXact[pgprocno];
    TransactionId xid;
    xid = pgxact->xmin; /* fetch just once */

    /*
     * If the transaction has no XID assigned, we can skip it; it
     * won't have sub-XIDs either.  If the XID is >= xmax, we can also
     * skip it; such transactions will be treated as running anyway
     * (and any sub-XIDs will also be >= xmax).
     */
    if (!TransactionIdIsNormal(xid)
        || !NormalTransactionIdPrecedes(xid, xmax))
        continue;

    if (NormalTransactionIdPrecedes(xid, xmin))
        xmin = xid;

    /* Add XID to snapshot. */
    snapshot->xip[count++] = xid;

    ...
}
```
当事务提交的时候:

```c 
static void
CommitTransaction(void)
{
    ...

    /*
     * We need to mark our XIDs as committed in pg_xact.  This is where we
     * durably commit.
     */
    latestXid = RecordTransactionCommit();

    /*
     * Let others know about no transaction in progress by me. Note that this
     * must be done _before_ releasing locks we hold and _after_
     * RecordTransactionCommit.
     */
    ProcArrayEndTransaction(MyProc, latestXid);

    ...
}
static TransactionId
RecordTransactionCommit(void)
{
    bool markXidCommitted = TransactionIdIsValid(xid);

    /*
     * If we haven't been assigned an XID yet, we neither can, nor do we want
     * to write a COMMIT record.
     */
    if (!markXidCommitted)
    {
        ...
    } else {
        XactLogCommitRecord(xactStopTimestamp,
                            nchildren, children, nrels, rels,
                            nmsgs, invalMessages,
                            RelcacheInitFileInval, forceSyncCommit,
                            MyXactFlags,
                            InvalidTransactionId /* plain commit */ );

        ....
    }

    if ((wrote_xlog && markXidCommitted &&
         synchronous_commit > SYNCHRONOUS_COMMIT_OFF) ||
        forceSyncCommit || nrels > 0)
    {
        XLogFlush(XactLastRecEnd);

        /*
         * Now we may update the CLOG, if we wrote a COMMIT record above
         */
        if (markXidCommitted)
            TransactionIdCommitTree(xid, nchildren, children);
    }

    ...
}

```
这里的 xlog 是指 WAL.如果发生故障，pg可以通过WAL里面的内容来恢复数据。先写WAL，然后`TranscationIdCommitTree`再把事务的状态更新到`clog`中(commit log).如果一个事物没有xid,比如只读的，WAL和clog就没必要写入了。如果一个事物被中止，状态仍然会被同步到WAL和clog中，但数据不会被立即写入到磁盘中。因为即使crash了，也不会丢失信息。

当事物完成后，需要通知整个系统:

```c 
void
ProcArrayEndTransaction(PGPROC *proc, TransactionId latestXid)
{
    /*
     * We must lock ProcArrayLock while clearing our advertised XID, so
     * that we do not exit the set of "running" transactions while someone
     * else is taking a snapshot.  See discussion in
     * src/backend/access/transam/README.
     */
    if (LWLockConditionalAcquire(ProcArrayLock, LW_EXCLUSIVE))
    {
        ProcArrayEndTransactionInternal(proc, pgxact, latestXid);
        LWLockRelease(ProcArrayLock);
    }

    ...
}

static inline void
ProcArrayEndTransactionInternal(PGPROC *proc, PGXACT *pgxact,
                                TransactionId latestXid)
{
    ...

    /* Also advance global latestCompletedXid while holding the lock */
    if (TransactionIdPrecedes(ShmemVariableCache->latestCompletedXid,
                              latestXid))
        ShmemVariableCache->latestCompletedXid = latestXid;
}


```
这里我们通过锁的方式独占地更新 `latestCompletedXid`的值，snapshot 创建的需要获取其值以设置 `xmax`.


## Links
1. [How Postgres Makes Transactions Atomic](https://brandur.org/postgres-atomicity)
2. [Can I rely on it that every single update statement in postgresql is atomic?](https://stackoverflow.com/questions/54934087/can-i-rely-on-it-that-every-single-update-statement-in-postgresql-is-atomic)
3. [PostgreSQL的事务隔离和MVCC](https://schecterdamien.github.io/2019/04/24/pg-mvcc/)
