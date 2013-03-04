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
