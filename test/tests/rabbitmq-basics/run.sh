#!/usr/bin/env bash
set -Eeuo pipefail

# https://www.rabbitmq.com/tutorials/tutorial-one-python.html

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

serverImage="$1"

clientImage="$("$dir/../image-name.sh" librarytest/rabbitmq-basics "$serverImage")"
"$dir/../docker-build.sh" "$dir" "$clientImage" <<EOD
FROM python:3.7-alpine
# ensure pip does not complain about a new version being available
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
RUN pip install pika==1.1.0
COPY dir/*.py /usr/local/bin/
EOD

cname="rabbitmq-container-$RANDOM-$RANDOM"
cid="$(docker run -d --name "$cname" "$serverImage")"
trap "docker rm -vf $cid > /dev/null" EXIT

client() {
	docker run -i --rm \
		--link "$cname":rabbitmq \
		"$clientImage" \
		"$@"
}

. "$dir/../../retry.sh" 'client testconn.py'

test-send-recv() {
	local payload="$1"; shift
	client send.py "$payload"
	response="$(client receive.py)"
	if [ "$payload" != "$response" ]; then
		echo >&2 "error: expected '$payload' but got '$response' instead"
		return 1
	fi
}

test-send-recv 'hello'
test-send-recv "$RANDOM"
test-send-recv $'a\nb\nc\td'
