#! /usr/bin/env python
# encoding: utf-8
# vim:fenc=utf-8
#
# Copyright © 2016 Stefano Stella <mprenditore@gmail.com>
#                  Andrea Mistrali< andrea.mistrali@gmail.com>
#
# Distributed under terms of the GPL license.
#
# git_ms
#
# $Id$
#

"""
GIT ManagmentScript

"""

import logging
import argparse
import sys
import os

from gitlab import Gitlab
from ConfigParser import ConfigParser

config = {"host": "http://gitlab.server.domain",  # gitlab host
    "token": "REPLACE_WITH_TOKEN_FROM_GITLAB",  # gitlab token
    "logfile": "/tmp/git_ms.log",  # Log file (full path)
    "loglevel": "INFO",  # default logging level, NOTSET disables logging
    }  # NOQA

basedir = os.path.dirname(sys.argv[0])
cfg = ConfigParser()
cfg.read('%s/git_ms.ini' % basedir)
config.update(dict(cfg.items('DEFAULT')))

# Set up Logging
try:
    logging.basicConfig(filename=config.get('logfile'),
            level=config.get('loglevel'),
            format='%(asctime)s %(module)s:%(lineno)s [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S')
except IOError:
    logging.warning("Unable to open logfile '%s', logging to sys.stderr" %
            config.get('logfile'))
    logging.basicConfig(level=config.get('loglevel'),
            format='%(asctime)s %(module)s:%(lineno)s [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S')


class GitUsers(Gitlab):

    """docstring for GitUsers"""

    def __init__(self, host=config.get('host'), token=config.get('token')):
        super(GitUsers, self).__init__(host, token)
        print "Welcome %s to GIT Managment Script" % self.currentuser().get('name')

    def list_it(self, whatList):
        tmpList = {}
        i = 1
        while True:
            if whatList == "users":
                tlist = self.getusers(per_page=20, page=i)
                whatGet = "username"
            if whatList == "projects":
                tlist = self.getprojects(per_page=20, page=i)
                whatGet = "name_with_namespace"
            if whatList == "projectsall":
                tlist = self.getprojectsall(per_page=20, page=i)
                whatGet = "name_with_namespace"

            if len(tlist) == 0:
                break
            for l in tlist:
                tmp = l.get(whatGet)
                tmpList[tmp] = l
            i = i + 1
        return tmpList

    @property
    def ulist(self):
        ulist = self.list_it('username')

    @property
    def plistall(self):
        plistall = self.list_it('projectsall')

    @property
    def plist(self):
        plist = self.list_it('projects')

    def copy_user(self, user, usercp):
        print "not implemented yet"

    def get_uid(self, user):
        print "not implemented yet"

    def get_projects(self, id):
        print "not implemented yet"


def parseArgs():
    description = """
    Manage Gitlab users
    """
    parser = argparse.ArgumentParser(description=description,
                                     epilog='Token key is needed to login')

    group = parser.add_mutually_exclusive_group()

    parser.add_argument('--dumpcfg', default=False,
                       action='store_true', help='dump default configuration')

    parser.add_argument('-u', '--user', default=False,
                       metavar='<user>', help='select the user to manage')

    parser.add_argument('-U', '--userorg', default=False,
                       metavar='<userorg>', help='select the user to copy')

    parser.add_argument('-n', '--name', default=False,
                       metavar='<name>', help='select the name for the user to manage')

    parser.add_argument('-e', '--email', default=False,
                       metavar='<email>', help='select the email for the user to manage')

    parser.add_argument('-w', '--password', default=False,
                       metavar='<password>', help='select the password for the user to manage')

    # group.add_argument('-a', '--add', default=False,
    #                    action='copy_user',
    #                    help='this will add the user (-u) to gitlab')

    # group.add_argument('-l', '--list', default=False,
    #                    action='list_users', help='list all users')

    parsed = parser.parse_args()
    # if type(parsed.msg) in [list, tuple]:
    #     parsed.msg = ' '.join(parsed.msg)
    # parsed.msg = parsed.msg.replace('\\n', '\n')

    # if parsed.headers:
    #     parsed.headers = [h.strip() for h in parsed.headers.split(',')]
    # else:
    #     parsed.headers = []
    return parsed


def check_var(quest=""):
    while True:
        var = raw_input(quest)
        var = var.strip()
        if var != "":
            return var
        else:
            logging.error("Value not accepted")


def main():
    parsed = parseArgs()
    print "parseArgs: %s" % (parsed)
    if parsed.name is False:
        parsed.name = check_var("Insert Full name for the user: ")
    if parsed.user is False:
        parsed.user = check_var("Insert Username for the user: ")
    if parsed.userorg is False:
        parsed.userorg = check_var("Insert the UsernameToCopy from: ")
    if parsed.email is False:
        parsed.email = check_var("Insert E-mail for the user: ")
    if parsed.password is False:
        parsed.password = check_var("Insert Password for the user: ")
    print "parseArgs: %s" % (parsed)
    git = GitUsers()

# If we have been called as 'python <script>' let's call main function
if __name__ == "__main__":
    main()
