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

test: all
	rebar skip_deps=true eunit

#################
# Starting dummy node
# NOTE: This is not for production! 
# 		Use /rel/erlattest/bin/erlattest start instead

NODE_START=exec erl -pa $(PWD)/ebin -pa $(PWD)/deps/*/ebin -boot start_sasl -s riemann -config $(PWD)/app.config -smp enabled

start: app
	$(NODE_START) 

#################
# Analysis

DIALYZER_OPTS = -Wrace_conditions -Werror_handling -Wunderspecs
DEPS_PLT=$(PWD)/.riemann_deps_plt
ERLANG_DIALYZER_APPS = asn1 \
                       compiler \
                       crypto \
                       edoc \
                       edoc \
                       erts \
                       eunit \
                       eunit \
                       gs \
                       hipe \
                       inets \
                       kernel \
                       mnesia \
                       mnesia \
                       observer \
                       public_key \
                       runtime_tools \
                       runtime_tools \
                       ssl \
                       stdlib \
                       syntax_tools \
                       syntax_tools \
                       tools \
                       webtool \
                       xmerl

~/.dialyzer_plt:
	@echo "ERROR: Missing ~/.dialyzer_plt. Please wait while a new PLT is compiled"
	@dialyzer --build_plt --apps $(ERLANG_DIALYZER_APPS)
	@echo "now try your build again"

$(DEPS_PLT):
	@dialyzer --output_plt $(DEPS_PLT) --build_plt -r deps 

dialyzer: $(DEPS_PLT) ~/.dialyzer_plt
	@dialyzer $(DIALYZER_OPTS) $(DIALYZER_OPTS) --plts ~/.dialyzer_plt $(DEPS_PLT) -I deps --src src
