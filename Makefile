.PHONY: deps

all: deps compile

compile:
	rebar compile

deps:
	rebar get-deps

clean:
	rebar clean

app:
	rebar compile skip_deps=true

test:
	rebar skip_deps=true eunit

#################
# Starting dummy node
# NOTE: This is not for production! 
# 		Use /rel/erlattest/bin/erlattest start instead

NODE_START=exec erl -pa $(PWD)/ebin -pa $(PWD)/deps/*/ebin -boot start_sasl -s riemann -config $(PWD)/app.config -smp enabled

start: app
	$(NODE_START) 
