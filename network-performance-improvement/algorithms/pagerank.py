import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "pagerank", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

st = time.time()
session.network.centrality(
    selfLinks=True,
    nThreads=args.nthreads,
    logLevel="aggressive",
    pagerank="unweight",
    pagerankAlpha=0.85,
    pagerankTolerance=1e-9,
    links={"name": "links"},
    outNodes={"name": "out", "replace": True})
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
