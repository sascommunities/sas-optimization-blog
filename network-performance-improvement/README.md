# Network and Network Optimization Performance Improvements in SAS Viya 2020.1

This repository contains the code for running the performance tests found the blog "Network and Network Optimization Performance Improvements in SAS Viya 2020.1."

## Setup

* Download data you wish to run. Most of the data in the blog are from [the SNAP repository](http://snap.stanford.edu/data/soc-RedditHyperlinks.html).
* Remove any header lines and ensure the data file is tab separated (or modify `algorithms/helper.py` to handle the data format you have).
* Obtain the host name and port where your SAS Viya installation is running and modify `casrc.txt` accordingly. The `algorithms/helper.py` file handles various setup including creating a session on your CAS server.

## Running the tests

The scripts for each algorithm are found in the algorithms folder and can be run individually. For example, you can do:
``` python
python algorithms/clique.py email-Enron.txt
```

To see more options, run:
``` python
python algorithms/clique.py -h
```

You can also run all the tests in a single batch job with the `runall.py`. However, to use this script, you must modify the `DATAPATH` variable at the top of the file.

When running these scripts, a `saslogs.txt` file will be created and appended to with each run. This file will contain the log output from SAS. The output will be printed to stdout and will show the runtime, for example:
```
sas-network, clique, email-Enron.txt, nThreads=8
================================================
  build elapsed:  0.070
  algo  elapsed:  0.250
  total elapsed:  0.398
```
