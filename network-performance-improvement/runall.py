import sys
import subprocess as sp

PYTHON = sys.executable
DATAPATH = "<your-data-folder-path-here>"

small_graphs = [
    "email-Enron.txt",
    "soc-Epinions1.txt"
]
med_graphs = [
    "web-Google.txt",
    "soc-pokec-relationships.txt"
]
large_graphs = [
    "com-orkut.ungraph.txt",
    "wikipedia_link_en.txt"
]

sp.run("date", shell=True, check=True)


for i in range(4):

    for algo in [
        "jaccard",
        "betweenness",
        "closeness"
    ]:
        for graph in small_graphs:
            gpath = f"{DATAPATH}/{graph}"
            gpath_weighted = gpath.rsplit(".txt", 1)[0] + "_weighted.txt"
            sp.call([PYTHON, f"algorithms/{algo}.py", gpath])
            if algo != "jaccard":
                sp.call([PYTHON, f"algorithms/{algo}.py", gpath_weighted, "--weighted"])

    for algo in [
        "weakconcomp",
        "strongconcomp",
        "biconcomp",
        "spanningforest",
        "kcore",
        "shortestpath",
        "pagerank",
        "clusteringcoeff",
        "clique",
    ]:
        for graph in med_graphs + large_graphs:
            if algo == "clique" and graph in large_graphs:
                continue

            gpath = f"{DATAPATH}/{graph}"
            gpath_weighted = gpath.rsplit(".txt", 1)[0] + "_weighted.txt"
            sp.call([PYTHON, f"algorithms/{algo}.py", gpath])
            if algo == "spanningforest" or algo == "shortestpath" or algo == "pagerank":
                sp.call([PYTHON, f"algorithms/{algo}.py", gpath_weighted, "--weighted"])
