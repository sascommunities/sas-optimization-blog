import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "jaccard similarity", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

st = time.time()
session.network.nodesimilarity(
    jaccard=True,
    nThreads=args.nthreads,
    logLevel="aggressive",
    links={"name": "links"},
    outsimilarity={"name": "outSim", "replace": True})
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
