# smartmerge

A lightweight Stata command that augments **merge** by checking what happens if you merge on *unique* combinations of the key variables.  

```
net install smartmerge, from("https://raw.githubusercontent.com/rdahis/smartmerge/main/") force
```

## Why?

When either the master or using data contain duplicate keys, `merge` behaves as documented but the resulting observation counts can be hard to interpret. `smartmerge` shows you – in a single step – what the merge result would be **if duplicates were dropped first** so you can see whether duplicates are the root cause of weird merge counts.

## Usage

`smartmerge` mirrors the syntax of Stata's native `merge`. Everything after the command name is passed through verbatim to `merge`.

```
smartmerge 1:m id using survey2, keep(match master)
```

The final dataset in memory is identical to what you would get from the call to `merge` alone. A diagnostic table for the duplicate-free merge is printed to the Results window.

## Contributing

Feel free to open issues or pull requests. This repo is intentionally minimal – PRs that add tests, real-world examples, or performance improvements are very welcome. 