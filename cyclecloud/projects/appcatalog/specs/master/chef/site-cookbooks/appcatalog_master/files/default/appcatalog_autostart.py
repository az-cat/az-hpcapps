#!/usr/bin/env python

from sge import get_sge_jobs, get_sge_job_details
import json
import jetpack.config
from urllib2 import urlopen, Request

def _get_jobs():
    job_details = get_sge_job_details()
    jobs = get_sge_jobs()

    metadata_url = "http://169.254.169.254/metadata/instance?api-version=2017-08-01"
    metadata_req = Request(metadata_url, headers={"Metadata" : True})
    metadata_response = urlopen(metadata_req)
    vm_metadata = json.load(metadata_response)

    subscription_id = vm_metadata["compute"]["subscriptionId"]

    node_config = jetpack.config.get()

    # Process all the jobs
    autoscale_requests = []
    for job in jobs:

        # Ignore jobs in "held" or "error" states
        if "h" in job["job_state"] or "e" in job["job_state"]:
            continue

        detail = job_details[job["job_number"]]

        slot_type = None
        if 'hard_resources' in detail:
            slot_type = detail["hard_resources"].get("slot_type", None)

        slots_per_job = 1
        if 'pe_range' in detail and 'min' in detail['pe_range']:
            slots_per_job = int(detail['pe_range']['min'])

        average_runtime = None
        if 'context' in detail and 'average_runtime' in detail['context']:
            average_runtime = int(detail['context']['average_runtime'])

        autoscale_request = {
            'Name': slot_type,
            'TargetCoreCount': slots_per_job
        }

        image_resource_id = None
        if slot_type != "execute":
            if 'context' in detail and 'image_id' in detail['context']:
                image_resource_id = detail['context']['image_id']


            if image_resource_id is None:
                print "WARNING: Job %s has non-execute slottype, but application image name not provided. Autoscaling %s nodes." % (job["job_number"], slot_type)
                print "WARNING: Job details %s" % detail
            else:
                autoscale_request = {
                    'Name': slot_type,
                    'Extends': 'execute',
                    'ImageId': image_resource_id,
                    'TargetCoreCount': slots_per_job,
                    'Configuration': {
                        'gridengine': {
                            'slot_type' : slot_type
                        }
                    },
                    'Dynamic': True
                }

                if 'context' in detail and 'machine_type' in detail['context']:
                   autoscale_request["MachineType"] = detail['context']['machine_type']
                    
                if 'context' in detail and 'ppn' in detail['context']:
                    ppn = detail['context']['ppn']
                    autoscale_request['Configuration']['gridengine']['slots'] = ppn
                    autoscale_request['CoreCount'] = ppn

        if 'context' in detail and 'autostop' in detail['context']:
            # cyclecloud.cluster.autoscale.stop_enabled
            if "Configuration" not in autoscale_request:
                autoscale_request["Configuration"] = {}
            
            stop_enabled = True
            if detail['context']['autostop'].lower() == 'false':
                stop_enabled = False

            autoscale_request["Configuration"]["cyclecloud"] = {
                'cluster': {
                    'autoscale': {
                        'stop_enabled': stop_enabled 
                    }
                }
            }
            

        print "Autoscale req: %s" % autoscale_request
        autoscale_requests.append(autoscale_request)

    return autoscale_requests

if __name__ == "__main__":
    import jetpack.autoscale
    jetpack.autoscale.update(_get_jobs())