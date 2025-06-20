{smcl}
{* *! version 1.0.0 25jun2025}

{title:Title}

{phang2}{cmd:smartmerge} {hline 2} Merge two datasets AND report results of a duplicate-insensitive merge.

{title:Syntax}

{p 8 15 2}{cmd:smartmerge} {it:merge_type} {it:varlist} {cmd:using} {it:filename}{cmd:,} [{it:merge_options}]

{p 8 8 2}The syntax is identical to Stata's built-in {help merge} command. All
options that {cmd:merge} accepts can be passed through unchanged.

{title:Description}

{pstd}{cmd:smartmerge} performs the standard {cmd:merge} specified by the user
and leaves the merged data in memory. In addition, it:

{p 4 8 2}1. Creates temporary versions of the master and using datasets that contain
only the key variables and no duplicates.

{p 4 8 2}2. Re-runs the merge on these {it:unique} datasets and displays the _merge
table so the user can quickly diagnose problems caused by duplicate keys.

{pstd}The auxiliary merge is for diagnostics only – it does not alter the data that
remain in memory.

{title:Options}

{phang}{opt detail(#)}  After the counts, list the first {it:#} duplicate key combinations found in each file.  Default is 10.  If no duplicates exist nothing is listed.

{phang}{cmd:duplist(}{it:pfx}{cmd:)}  Save duplicate rows to {it:pfx}{cmd:_master.dta} and {it:pfx}{cmd:_using.dta}.  Quoted or unquoted prefixes allowed.  Without this option duplicates are kept only in temporary files.

{phang}{cmd:keepvars(}{it:varlist}{cmd:)}  After the merge keep only the listed variables plus {_merge}.  Useful when merging huge files but you need only a few columns.

{phang}{opt hash}  When tagging duplicates use {helpb sort##hashsort:hashsort} which is faster on very large datasets.

{phang}{opt nodiag}  Suppress all textual diagnostics; only the merge summaries appear and r() scalars are returned. 

{title:Example}

{phang}{cmd:smartmerge 1:m id using "survey2.dta", keepusing(age sex)}

{title:Also see}

{psee}Help: {help merge} 

{title:Author}

{pstd}Ricardo Dahis  (ricardo.dahis@monash.edu)

{pstd}Feel free to report issues or contribute at:
{browse "https://github.com/rdahis/smartmerge"}
