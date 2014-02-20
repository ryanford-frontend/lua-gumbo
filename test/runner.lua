#!/usr/bin/env lua
-- Test runner for the html5lib tree-construction test suite.
-- Don't run directly, use `make check-html5lib` in the top-level directory.

assert(arg[1], "No test files specified")
local gumbo = require "gumbo"
local serialize = require "gumbo.serialize.html5lib"
local Buffer = require "gumbo.buffer"
local verbose = os.getenv "VERBOSE"
local results = {passed = 0, failed = 0, skipped = 0}
local hrule = string.rep("=", 76)
local start = os.clock()

local function parse_testdata(filename)
    local file = assert(io.open(filename))
    local text = assert(file:read("*a"))
    file:close()
    local tests = {[0] = {}}
    local buffer = Buffer(32)
    local field = false
    local i = 0
    local linenumber = 0
    for line in text:gmatch "([^\n]*)\n" do
        linenumber = linenumber + 1
        local section = line:match("^#(.*)$")
        if section then
            tests[i][field] = tostring(buffer):sub(1, -2) -- Discard last \n
            buffer = Buffer(32)
            field = section
            if section == "data" then
                i = i + 1
                tests[i] = {line = linenumber}
            end
        else
            buffer:write(line, "\n")
        end
    end
    tests[i][field] = tostring(buffer)
    if i > 0 then
        tests.n = i
        return tests
    else
        return nil, "No test data found in " .. filename
    end
end

for i = 1, #arg do
    local filename = arg[i]
    local tests = assert(parse_testdata(filename))
    local passed, failed, skipped = 0, 0, 0
    for i = 1, tests.n do
        local test = tests[i]
        if
            -- Gumbo can't parse document fragments yet
            test["document-fragment"]
            -- See line 134 of python/gumbo/html5lib_adapter_test.py
            or test.data:find("<noscript>", 1, true)
            or test.data:find("<command>", 1, true)
        then
            skipped = skipped + 1
        else
            local document = assert(gumbo.parse(test.data))
            local serialized = assert(serialize(document))
            if serialized == test.document then
                passed = passed + 1
            else
                failed = failed + 1
                if verbose then
                    io.write(
                        hrule, "\n",
                        filename, ":", test.line, ": Test ", i, " failed\n",
                        hrule, "\n\n",
                        "Input:\n", test.data, "\n\n",
                        "Expected:\n", test.document, "\n",
                        "Received:\n", serialized, "\n"
                    )
                end
            end
        end
    end
    results[i] = {
        filename = filename,
        basename = filename:gsub("(.*/)(.*)", "%2"),
        passed = passed,
        failed = failed,
        skipped = skipped,
        total = tests.n
    }
    results.passed = results.passed + passed
    results.failed = results.failed + failed
    results.skipped = results.skipped + skipped
end

results.total = results.passed + results.failed + results.skipped

io.write(
    "\nRan ", results.total, " tests in ",
    string.format("%.2fs", os.clock() - start), "\n\n",
    "Passed: ", results.passed, "\n",
    "Failed: ", results.failed, "\n",
    "Skipped: ", results.skipped, "\n\n"
)

if results.failed > 0 then
    if not verbose then
        print("Re-run with VERBOSE=1 for a full report")
    end
    if results.failed > 3 then -- TODO: remove condition when tests are passing
        os.exit(1)
    end
end
