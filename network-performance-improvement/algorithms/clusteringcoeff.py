import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "local clustering coefficient", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

st = time.time()
session.network.centrality(
    clusteringCoef=True,
    nThreads=args.nthreads,
    logLevel="aggressive",
    links={"name": "links"},
    outNodes={"name": "out", "replace": True}),
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
