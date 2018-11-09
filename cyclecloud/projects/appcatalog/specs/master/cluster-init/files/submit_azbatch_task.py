#! /usr/bin/env python
import json
import sys
import time
import argparse
from urllib import urlretrieve
from subprocess import CalledProcessError, check_output
from os import makedirs, chdir, environ, getcwd, path

timestamp=int(time.time())
workdir=None


def _catch_sys_error(cmd_list):
    try:
        output = check_output(cmd_list)
        # print cmd_list
        print output
    except CalledProcessError as e:
        print "Error with cmd: %s" % e.cmd
        print "Output: %s" % e.output
        raise

def parseBatchCommand(batch_cmd):
    job_cmd = batch_cmd.replace("bash -c ","")
    job_cmd = job_cmd.replace("batch_wrapper.sh ","")
    job_cmd = job_cmd.replace("'","")
    job_cmd = workdir + "/" + job_cmd.lstrip()
    return job_cmd

def submitJob(args, job_cmd):
    app = args.app
    image_id = args.image_id
    num_nodes = args.num_nodes
    ppn = args.ppn
    machine_type = args.machine_type
    # slot_type=app + "-" + num_nodes + "-" + ppn
    slot_type = app + "-" + str(timestamp)
    num_cores = str(int(num_nodes) * int(ppn))

    job_file_name = "submit_" + app + ".sh"
    f = open(job_file_name, "w")
    f.write("#! /bin/bash\n")
    f.write("#$ -N " + app + "\n")
    f.write("#$ -o " + workdir + "/stdout/" + app + '.$JOB_ID' + "\n")
    f.write("#$ -e " + workdir + "/stderr/" + app + '.$JOB_ID' + "\n")
    f.write("#$ -l slot_type=" + slot_type + "\n")
    f.write("#$ -l affinity_group=" + "default" + "\n")
    f.write("#$ -ac ppn=" + ppn + "\n")
    f.write("#$ -ac image_id=" + image_id + "\n")
    
    if args.machine_type is not None:
        f.write("#$ -ac machine_type=" + args.machine_type + "\n")

    f.write("#$ -pe mpi " + num_cores + "\n")
    f.write("\n")
    f.write(job_cmd + "\n")
    f.close()

    _catch_sys_error(["chmod", "a+x", job_file_name])
    _catch_sys_error(["qsub", "-cwd", "-V", job_file_name])

def create_workdir(app):
    dirname=app + "_" + str(timestamp)
    if not path.isdir(dirname):
        makedirs(dirname)
        makedirs(dirname + "/output")
        makedirs(dirname + "/stderr")
        makedirs(dirname + "/stdout")
    chdir(dirname)
    global workdir
    workdir = getcwd()
    print "Workdir created: %s" % dirname

def downloadResourceFiles(resourceFiles):
    chdir(workdir)
    for resource in resourceFiles:
        print "Fetching resource file %s" % resource["filePath"]
        urlretrieve (resource["blobSource"], resource["filePath"])
        if ".sh" in resource["filePath"]:
            _catch_sys_error(["chmod", "a+x", resource["filePath"]])

def setEnvVars(environmentSettings):
    for setting in environmentSettings:
        print "Setting Env %s: %s" % (setting["name"], setting["value"])
        environ[setting["name"]] = setting["value"]

    # also set variables that are not in the taskjson
    environ["SHARED_DIR"] = workdir
    print "Setting Env %s: %s" % ("SHARED_DIR", workdir)
    environ["OUTPUT_DIR"] = workdir + "/output"
    print "Setting Env %s: %s" % ("OUTPUT_DIR", workdir + "/output")


def parse_batch_task(task_file):
    task = None
    with open(task_file, 'r') as file:
        task = json.load(file)

    return task


def main():
    parser = argparse.ArgumentParser(description="usage: %prog [options]")
    parser.add_argument("-b", "--batch_json",
                      dest="taskfile",
                      required=True,
                      help="Azure Batch Taskfile in json")

    parser.add_argument("-a", "--application",
                      dest="app",
                      required=True,
                      help="Application name")

    parser.add_argument("-i", "--image_id",
                      dest="image_id",
                      required=True,
                      help="Azure Image Id to use ")

    parser.add_argument("-n", "--num_nodes",
                      dest="num_nodes",
                      required=True,
                      help="Number of nodes of use for job")

    parser.add_argument("-p", "--ppn",
                      dest="ppn",
                      required=True,
                      help="Number of processes per node")

    parser.add_argument("-m", "--machine_type",
                      dest="machine_type",
                      help="Specify a machine type to use")

    parser.add_argument("-t", "--timestamp",
                      dest="timestamp",
                      help="specify a timestamp. Useful for resubmitting old submissions")

    args = parser.parse_args()

    if args.timestamp is not None:
        global timestamp
        print "**** Timestamp specified: %s" % args.timestamp
        timestamp = args.timestamp

    task = parse_batch_task(args.taskfile)
    create_workdir(args.app)
    downloadResourceFiles(task['resourceFiles'])
    setEnvVars(task['environmentSettings'])
    job_cmd = parseBatchCommand(task['commandLine'])

    submitJob(args, job_cmd)


if __name__ == "__main__":
    main()
