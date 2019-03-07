#! /bin/sh
#
# kill_expired_docker.sh
# Copyright (C) 2018 steste <steste@MAC128>
#
# Distributed under terms of the MIT license.
#

for d in $(docker ps --filter "status=running" -q | xargs docker inspect --format '{{.ID}}={{.State.StartedAt}}' 2>/dev/null); do
    id=$(echo $d | cut -d= -f1)
    started=$(echo $d | cut -d= -f2)
    date -d $started +%s
done

