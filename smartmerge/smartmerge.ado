program define smartmerge, sortpreserve rclass
    version 14.0

    /*
    ---------------------------------------------------------------------
    smartmerge
    Author: Ricardo Dahis (initial scaffolding by AI assistant)
    Date  : 25 Jun 2025

    Syntax (mirrors Stata's merge):
        smartmerge <merge_type> varlist using filename [, merge_options]

    The command performs two steps:
      1. Executes Stata's built-in merge with the arguments supplied by the user (so the data in memory after smartmerge ends are exactly what the standard merge would leave).
      2. Repeats the merge on the *unique* combinations of the key variables in each dataset, displaying the results so the user can easily spot merge problems created by duplicates.

    For now, the implementation keeps things simple:
      • Only the canonical syntax above is supported (no if/in).
      • All merge options after the comma are passed straight through to merge.
      • The results of the second merge are shown in the Results window via a tabulation of _merge. They are *not* saved.

    ---------------------------------------------------------------------
    */

    /* Capture the full argument list (everything after "smartmerge ") */
    local _cmd `"`0'"'

    /* Bail out early if nothing was supplied */
    if "`_cmd'" == "" {
        di as err "syntax: smartmerge <merge_type> varlist using filename [, options]"
        exit 198
    }

    /*******************************************************************
      ── Step 1: Parse pieces we need for the unique-level merge ─────────────────
    *******************************************************************/
    /*
       We only need:
         1. merge type   (first token)
         2. varlist      (until we hit the token "using")
         3. using file   (token immediately after "using")
       Everything after that (including the comma) is stored in `opts'.
    */
    gettoken _mergetype  0 : 0, parse(" ")
    gettoken _rest       0 : 0, parse(" ")

    /* Build varlist */
    local _varlist ""
    while "`_rest'" != "using" & "`_rest'" != "" {
        local _varlist "`_varlist' `_rest'"
        gettoken _rest 0 : 0, parse(" ")
    }

    if "`_rest'" != "using" {
        di as err "smartmerge: unable to locate keyword 'using' in command line."
        exit 198
    }

    /* Now grab the filename after "using" */
    gettoken _usingfile 0 : 0, parse(" ,")
    if "`_usingfile'" == "" {
        di as err "smartmerge: missing filename after 'using'."
        exit 198
    }

    /* Whatever is left (could be empty) are options (including leading comma) */
    local _opts `"`0'"'

    /*******************************************************
        Handle extra custom options: detail() duplist()
    *******************************************************/
    local _detail 0
    if regexm(lower("`_opts'"), "detail\(([0-9]+)\)") {
        local __match = regexs(0)
        local _detail = real(regexs(1))
        local _opts : subinstr local _opts "`__match'" "" , all
    }
    else if regexm(lower("`_opts'"), "[, ]detail([ ,]|$)") {
        local _detail = 10
        local _opts : subinstr local _opts "detail" "" , all
    }

    /* duplist(prefix) option ; allow quoted or unquoted prefix */
    local _dupprefix ""
    if regexm(lower("`_opts'"), "duplist\(([^)]*)\)") {
        local __match    = regexs(0)
        local _dupprefix = regexs(1)
        /* strip possible quotes */
        local _dupprefix : subinstr local _dupprefix `"""' "" , all
        local _dupprefix : subinstr local _dupprefix "'"  "" , all
        local _opts : subinstr local _opts "`__match'" "" , all
    }

    /* nodiag option */
    local _quiet 0
    if regexm(lower("`_opts'"), "nodiag") {
        local _quiet 1
        local _opts : subinstr local _opts "nodiag" "" , all
    }

    /* keepvars(varlist) */
    local _keepvars ""
    if regexm("`_opts'", "keepvars\(([^)]+)\)") {
        local __match = regexs(0)
        local _keepvars = regexs(1)
        local _opts : subinstr local _opts "`__match'" "" , all
    }

    /* hash flag */
    local _hash 0
    if regexm(lower("`_opts'"), "hash") {
        local _hash 1
        local _opts : subinstr local _opts "hash" "" , all
    }

    /* tidy opts again */
    local _opts : list retokenize _opts

    /* unique flag */
    local _unique 0

    /* initialise duplicate counters */
    local N_master_dup 0
    local N_using_dup 0

    /*******************************************************************
      ── Step 2: Prepare temporary unique versions of each dataset ────────
    *******************************************************************/
    tempfile _master_unique _using_unique _master_orig

    /* Save the *current* dataset (master) exactly as the user has it. */
    quietly save "`_master_orig'", replace

    /* Build list of duplicates in master */
    preserve
        quietly keep `_varlist'
        quietly duplicates tag `_varlist', gen(_dup_tag)
        quietly count if _dup_tag
        local N_master_dup = r(N)
        if `N_master_dup' > 0 {
            quietly tempfile _dup_master
            quietly keep if _dup_tag
            quietly save "`_dup_master'", replace
            if "`_dupprefix'" != "" {
                quietly keep `_varlist'
                quietly duplicates drop
                quietly save "`_dupprefix'_master.dta", replace
            }
        }
        if `_quiet'==0 & `_detail'>0 {
            quietly use "`_dup_master'", clear
            quietly duplicates drop
            local __show = min(`_detail', _N)
            di as txt "First `__show' duplicate keys in master:" 
            list `_varlist' in 1/`__show', noobs
        }
    restore

    /* Now create unique master */
    preserve
        quietly keep `_varlist'
        quietly duplicates drop
        quietly save "`_master_unique'", replace
    restore

    /* Create unique using */
    preserve
        quietly use "`_usingfile'", clear
        quietly keep `_varlist'
        quietly duplicates tag `_varlist', gen(_dup_tag)
        quietly count if _dup_tag
        local N_using_dup = r(N)
        if `N_using_dup' > 0 {
            tempfile _dup_using
            quietly keep if _dup_tag
            quietly save "`_dup_using'", replace
            if "`_dupprefix'" != "" {
                quietly keep `_varlist'
                quietly duplicates drop
                quietly save "`_dupprefix'_using.dta", replace
            }
        }
        if `_quiet'==0 & `_detail'>0 {
            quietly use "`_dup_using'", clear
            quietly duplicates drop
            local __show = min(`_detail', _N)
            di as txt "First `__show' duplicate keys in using:" 
            list `_varlist' in 1/`__show', noobs
        }
        /* create unique dataset */
        quietly use "`_usingfile'", clear // reload
        quietly keep `_varlist'
        quietly duplicates drop
        quietly save "`_using_unique'", replace
    restore

    /*******************************************************************
      ── Step 3: Show duplicate-free merge first ─────────────────────────
    *******************************************************************/
    
    local __keyvars : list retokenize _varlist
    if `_quiet'==0 {
        di as txt "//---------------------------------------------------------//"
        di as txt "// Unique-level merge (duplicates dropped) on: `__keyvars'"
        di as txt "//---------------------------------------------------------//"
    }

    preserve
        quietly use "`_master_unique'", clear
        merge 1:1 `_varlist' using "`_using_unique'"
        /* merge prints its own summary table */
    restore

    di as txt ""
    
    /*******************************************************************
      ── Step 4: Perform the user-requested merge and keep it ────────────
    *******************************************************************/
    
    if `_quiet'==0 {
        di as txt "//---------------------------------------------------------//"
        di as txt "// Standard merge on: `__keyvars'"
        di as txt "//---------------------------------------------------------//"
    }
    
    quietly use "`_master_orig'", clear
    merge `_mergetype' `_varlist' using "`_usingfile'" `opts'

    /* Capture overall counts in r() for programmatic use */
    quietly count
    return scalar N = r(N)
    quietly count if _merge==3
    return scalar N_match = r(N)
    quietly count if _merge==1
    return scalar N_master = r(N)
    quietly count if _merge==2
    return scalar N_using = r(N)
    return scalar N_master_dup   = `N_master_dup'
    return scalar N_using_dup    = `N_using_dup'
    if "`_dupprefix'" != "" {
        return local dup_master_path "`_dupprefix'_master.dta"
        return local dup_using_path  "`_dupprefix'_using.dta"
    }
    else {
        if `N_master_dup'>0 return local dup_master_path "`_dup_master'"
        if `N_using_dup'>0  return local dup_using_path  "`_dup_using'"
    }

    /* Final dataset in memory is the full merge result */

    /* after final merge, keepvars */
    if "`_keepvars'" != "" {
        keep `_keepvars' _merge
    }

    /* automatic label */
    capture label define _sm_merge 1 "master only" 2 "using only" 3 "matched"
    capture label values _merge _sm_merge

end

// EOF 