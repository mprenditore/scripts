#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2017 stefano <stefano@sstella-laptop.etain.priv>
#
# Distributed under terms of the MIT license.

"""AWsShit

Usage:
    awshit.py list (instances | security_groups | network_interfaces | host_zones | custom_images | subnets) [options]
    awshit.py create (instance | security_group | network_interface | record_set) [options] [-a <amiId>] [-t <instType>] [-s <secDiskSize>] [-H <hostname>] [-d <domain>] [--subnet <subnet>] [--privip <privateIP>] [--sgroup <secGroup>] [--ahz <ahostzoneId>] [--ptrhz <ptrhostzoneId>]
    awshit.py add-dns (instance) [options] [-H <hostname>] [-d <domain>] [--privip <privateIP>] [--ahz <ahostzoneId>] [--ptrhz <ptrhostzoneId>]
    awshit.py (-h | --help)

Option:
    -h --help                    Show this screen
    -a, --ami <amiId>            Use that image-ami
    -t, --type <instType>        Type of the instance
    -s, --size <secDiskSize>     Secondary Disk size
    -H, --hostname <hostname>    Hostname (short)
    -d, --domain <domain>        Domain name
    --ahz <hostzoneId>           HostZone Id for A record
    --ptrhz <hostzoneId>         HostZone Id for PTR record
    --subnet <subnet>            Subnet
    --sgroup <secGroup>          Security Group
    --privip <privateIP>         Private IP
Options:
    --profile <profileName>      Profile Name saved on ~/.aws/conf [default: default]
    --region <regionName>        Region Name to work on [default: eu-central-1]

"""
from docopt import docopt
import boto3
import ipaddress
import botocore.errorfactory


def check_required(data, args):
    required_map = {'--ami': 'Ami Id',
                    '--domain': 'Domain',
                    '--hostname': 'Hostname',
                    '--ahz': 'HostZone Id for A record',
                    '--ptrhz': 'HostZone Id for PTR record',
                    '--sgroup': 'Security Group',
                    '--privip': 'Private IP',
                    '--subnet': 'Subnet',
                    '--type': 'Instance Type'}
    for k in args:
        if k in required_map and data.get(k) is None:
            while True:
                data[k] = raw_input("Insert value of '%s': " % required_map.get(k))
                if len(data[k]) > 0:
                    break
                else:
                    print "Empty Value, retry, you'll be more lucky!"
    return data


# Search inside the TAG array if there is a dict with key "Name" and return the "Value"
def get_name(res):
    n = [x.get('Value') for x in res.tags if x.get('Key') == 'Name']
    if len(n) >= 1:
        return n[0]
    else:
        return None


def list_instances():
    for i in ec2.instances.all():
        name = get_name(i) or 'No Name'
        print i.id, '-', name, '-', i.state['Name']


def list_subnets():
    for sn in ec2.subnets.all():
        if sn.tags:
            name = get_name(sn) or 'No Name'
            print sn.id, '-', name, '-', sn.cidr_block


def list_security_groups():
    for sg in ec2.security_groups.all():
        vpc_name = ec2.Vpc(sg.vpc_id).tags[0]['Value']
        if(vpc_name != "DO NOT REMOVE- EVER!"):
            sg_name = sg.tags[0]['Value'] if sg.tags is not None else "NoNameOnAWS"
            print sg.id, '-', ec2.Vpc(sg.vpc_id).tags[0]['Value'], '-', sg_name


def list_network_interfaces():
    for ni in ec2.network_interfaces.all():
        if ni.attachment is not None:
            name = ni.attachment.get('InstanceId', "AWS Behaviur")
            if name != "AWS Behaviur":
                name = get_name(ec2.Instance(ni.attachment['InstanceId'])) or "AWS Behaviur"
        else:
            name = "DETACHED"
        print ni.id, '-', ni.subnet.id, '(', ni.subnet.tags[0]['Value'], ')', '-', ni.private_ip_address, '-', name


def list_custom_images():
    for im in ec2.images.filter(DryRun=False, Owners=['self']):
        print im.image_id, '-', im.image_location.split('/')[1]


def list_host_zones():
    for hz in rt53.list_hosted_zones()['HostedZones']:
        print hz['Name'], '-', hz['Id']


def create_instance(data):
    required = ['--ami', '--domain', '--hostname', '--ahz', '--ptrhz',
                '--sgroup', '--privip', '--subnet', '--type']
    data = check_required(data, required)

    ami = data.get('--ami')
    domain = data.get('--domain')
    hostname = data.get('--hostname')
    privip = data.get('--privip')
    size = int(data.get('--size', 0))
    subnet = data.get('--subnet')
    sgroup = data.get('--sgroup')
    instType = data.get('--type')

    disks = [{
        'DeviceName': '/dev/xvda',
        'Ebs': {
            'VolumeSize': 10,
            'DeleteOnTermination': True,
            'VolumeType': 'gp2'},
    }]
    if size > 0:
        disks.append({
            'DeviceName': '/dev/xvdb',
            'Ebs': {
                'VolumeSize': size,
                'DeleteOnTermination': False,
                'VolumeType': 'gp2',
            }
        })

    instances = ec2.create_instances(
        ImageId=ami,
        MinCount=1,
        MaxCount=1,
        KeyName="root@sys",
        InstanceType=instType,
        NetworkInterfaces=[{
            'DeviceIndex': 0,
            'SubnetId': subnet,
            'Groups': [sgroup],
            'Description': '%s - network_interface' % hostname,
            'PrivateIpAddress': privip,
            'DeleteOnTermination': True
        }],
        BlockDeviceMappings=disks,
        UserData="""#cloud-config

hostname: %s
fqdn: %s.%s
manage_etc_hosts: true""" % (hostname, hostname, domain))

    inst = instances[0]
    inst.create_tags(Tags=[{'Key': 'Name', 'Value': hostname}])
    print "Instance Created"
    add_instanceDNS(data)


def add_instanceDNS(data):
    required = ['--domain', '--hostname', '--ahz', '--ptrhz', '--privip']
    data = check_required(data, required)

    domain = data.get('--domain')
    hostname = data.get('--hostname')
    ahz = data.get('--ahz')
    ptrhz = data.get('--ptrhz')
    privip = data.get('--privip')
    fqdn = '.'.join([hostname, domain])

    ptr = ipaddress.ip_address(unicode(privip)).reverse_pointer
    addSimpleRecord('A', ahz, fqdn, privip)
    addSimpleRecord('PTR', ptrhz, ptr, fqdn)
    print "Host DNS Updated"


def addSimpleRecord(rtype, hostzoneId, rname, rvalue):
    try:
        rt = session.client('route53')
        rt.change_resource_record_sets(
            HostedZoneId=hostzoneId,
            ChangeBatch={
                'Comment': 'Added by api',
                'Changes': [
                    {
                        'Action': 'CREATE',
                        'ResourceRecordSet': {
                            'Name': rname,
                            'Type': rtype,
                            'TTL': 300,
                            'ResourceRecords': [
                                {
                                    'Value': rvalue
                                }
                            ]
                        }
                    }
                ]
            }
        )
    # except Exception as e:
    except botocore.errorfactory.ClientError as e:
        print "# ERROR #: ", e


def cleanUp(arguments):
    # Clean up arguments
    for k, v in arguments.items():
        if v is False or v is None:
            del arguments[k]
    return arguments


def handleList(arguments):
    if 'list' in arguments:
        if 'instances' in arguments:
            list_instances()
        if 'security_groups' in arguments:
            list_security_groups()
        if 'network_interfaces' in arguments:
            list_network_interfaces()
        if 'host_zones' in arguments:
            list_host_zones()
        if 'custom_images' in arguments:
            list_custom_images()
        if 'subnets' in arguments:
            list_subnets()


def handleCreate(arguments):
    if 'create' in arguments:
        if 'instance' in arguments:
            create_instance(arguments)


def handleDNS(arguments):
    if 'add-dns' in arguments:
        if 'instance' in arguments:
            add_instanceDNS(arguments)


if __name__ == "__main__":
    arguments = cleanUp(docopt(__doc__, version='1.0'))
    profile_name = arguments.get('--profile')
    region_name = arguments.get('--region')
    session = boto3.Session(profile_name=profile_name)
    ec2 = session.resource('ec2', region_name=region_name)
    rt53 = session.client('route53')

    handleList(arguments)
    handleCreate(arguments)
    handleDNS(arguments)
