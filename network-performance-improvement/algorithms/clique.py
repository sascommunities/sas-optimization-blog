import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "clique", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

st = time.time()
session.network.clique(
    nThreads=args.nthreads,
    logLevel="aggressive",
    links={"name": "links"},
    maxCliques="all",
    out={"name": "out", "replace": True})
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
