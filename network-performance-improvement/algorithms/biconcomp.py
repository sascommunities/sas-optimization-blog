import helper
import time

args = helper.take_input()
helper.print_header("sas-network", "biconnected components", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

st = time.time()
session.network.biconnectedComponents(
    nThreads=args.nthreads,
    logLevel="aggressive",
    links={"name": "links"},
    outNodes={"name": "outNodes", "replace": True},
    outLinks={"name": "out", "replace": True})
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
