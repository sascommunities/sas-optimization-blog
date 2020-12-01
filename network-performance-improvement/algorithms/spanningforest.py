import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "spanning forest", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

st = time.time()
session.optnetwork.minSpanTree(
    nThreads=args.nthreads,
    logLevel="aggressive",
    links={"name": "links"},
    out={"name": "outLinks"})
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
