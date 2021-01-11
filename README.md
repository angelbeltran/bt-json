# bt-json

A terminal-based plugin for Google's [Bigtable](https://cloud.google.com/bigtable) querying tool, [cbt](https://cloud.google.com/bigtable/docs/cbt-overview).
Just an exercise in haskell I thought might also be useful.

# How To Build

Simply clone it locally and `stack build` it. The binary should be in the .stack-work directory.

# What It Does

You can do things like

```
cbt read from_a_table cells-per-column=1 | bt-json-exe'
```

to transform the output of `cbt` into machine-friendly json. You can further filter or map with [jq](https://stedolan.github.io/jq/), ie

```
cbt read from_a_table cells-per-column=1 | bt-json-exe | jq '.["justTheFieldINeed"]'
```

# Example

So instead of dealing with this...

```
----------------------------------------
first_key#123
  family:someBoolean                       @ 2020/07/16-14:45:48.602000
    "false"
  family:someNumber                        @ 2020/07/16-14:45:48.602000
    "1594932348"
  family:someText                          @ 2020/07/16-14:45:48.602000
    "abc123"
  family:someJSON                          @ 2020/07/16-14:45:48.602000
    "{\"key\": [\"value1\", 123, {\"nested\":\"value2\"}]}"
----------------------------------------
second_key#456
  family:someBoolean                       @ 2020/07/16-14:45:48.602000
    "true"
  family:someNumber                        @ 2020/07/16-14:45:48.602000
    "3234815949"
  family:someText                          @ 2020/07/16-14:45:48.602000
    "123abc"
  family:someJSON                          @ 2020/07/16-14:45:48.602000
    "{\"key\": [\"value1\", 123, {\"nested\":\"value2\"}]}"
```

...you deal with this

```
{
  "key": "first_key#123",
  "family:someBoolean": false,
  "family:someNumber": 1594932348,
  "family:someText": "abc123",
  "family:someJSON": {
    "key": [
      "value1",
      123,
      {
        "nested": "value2"
      }
    ]
  }
}
{
  "key": "second_key#456",
  "family:someBoolean": true,
  "family:someNumber": 3234815949,
  "family:someText": "123abc",
  "family:someJSON": {
    "key": [
      "value1",
      123,
      {
        "nested": "value2"
      }
    ]
  }
}
```
