import sys
import shutil
import jetpack.config

sys.path.append('.')
import ipcalc

# Create a hosts file with mappings for all IP addresses within your subnet
#
# Hostnames are in hex format to account for Windows hosts having a 15-char limit
#
# Sample entry:
# 10.198.2.10 ip-0AC6020A.ec2.internal ip-0AC6020A

# compute_vnet_hostames.py compute_subnet

suffix = None
alt_suffix = None
subnet = None
if len(sys.argv) > 1 and sys.argv[1].lstrip():
    subnet  = sys.argv[1].lstrip().lstrip('.')
    print "Arg1 :%s:" % (sys.argv[1])

print "Original fqdn: %s" % (jetpack.config.get()['cyclecloud']['instance']['hostname'])

if suffix is None:
    local_fqdn = jetpack.config.get()['cyclecloud']['instance']['hostname']
    suffix = local_fqdn.split('.')[1:]
    if suffix:
        suffix = ".".join(suffix)
        print "Found suffix : %s" % (suffix)
else:
    print "Overriding suffix : %s" % (suffix)

default_interface = jetpack.config.get()['network']['default_interface']
ipaddress = jetpack.config.get()['ipaddress']

print "interface %s" % (default_interface)
print "ipaddress %s" % (ipaddress)
print "subnet %s" % (subnet)

print "remove existing IP"
old = open("/etc/hosts", "r")
new = open("/etc/hosts.compute", "w")
for line in old.readlines():
    if not line.startswith(ipaddress):
        new.write(line)

old.close()
new.write("\n#The following was added for the separate compute subnet.\n")

print "starting for loop"
for ip in ipcalc.Network(subnet):
    octets = str(ip).split(".")
    hostname = "ip-{:02X}{:02X}{:02X}{:02X}".format(int(octets[0]), int(octets[1]), int(octets[2]), int(octets[3]))
    fqdn = ''
    if suffix:
        fqdn = "%s.%s" % (hostname, suffix)
    if alt_suffix:
        fqdn = "%s.%s" % (hostname, alt_suffix)

    # If FQDN is available, order should be "<ip> <fqdn> <shortname>"
    new.write("%s %s %s \n" % (ip, fqdn, hostname))

new.close()


# this indicates success
shutil.copyfile("/etc/hosts", "/etc/hosts.backup")

# atomic move as the last operation
shutil.move("/etc/hosts.compute", "/etc/hosts")
