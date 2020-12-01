import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "weakly connected components", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

st = time.time()
session.network.connectedComponents(
    nThreads=args.nthreads,
    logLevel="aggressive",
    links={"name": "links"},
    outNodes={"name": "out", "replace": True})
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
