```
   ______          __     ________              __                ________    ____
  / ____/___  ____/ /__  / ____/ /_  ___  _____/ /_____  _____   / ____/ /   /  _/
 / /   / __ \/ __  / _ \/ /   / __ \/ _ \/ ___/ //_/ _ \/ ___/  / /   / /    / /  
/ /___/ /_/ / /_/ /  __/ /___/ / / /  __/ /__/ ,< /  __/ /     / /___/ /____/ /   
\____/\____/\__,_/\___/\____/_/ /_/\___/\___/_/|_|\___/_/      \____/_____/___/  
```

# CodeChecker CLI

A CLI wrapper for the CodeChecker project.  This CLI bundles the [CodeChecker core libraries](https://github.com/coldbox-modules/codechecker-core) for use in the command line.

## Installation

```bash
install commandbox-codechecker
```

## Usage


To start a code review against your code, run this command:

```bash
codechecker run
```

### Arguments
                
* **categories** - Comma delimited list of categories of rules to run. Applies on top of existing include and excludes specified in `.codechecker.json`.
* **paths** - Comma delimited list of file globbing paths to scan. i.e. **.cf? (overrides `paths` in JSON)
* **minSeverity** - Minimum rule severity to consider. Level 1-5. (overrides `paths` in JSON)
* **excelReportPath** - Path to write Excel report to
* **verbose** = "false" - Output full list of files being scanned and all items found to the console
* **failOnMatch** = "false" - Sets a non-zero exit code if any matches are found

### JSON Configuration

If a `.codechecker.json` file is found in the current working directory, it will be picked up and used.  This file can contain the following keys:

- **paths** - Comma delimited list of file globbing paths to scan if nothing is passed to the command
- **minSeverity** - Minimum rule severity to consider if nothing is passed to the command
- **includeRules** - A struct of arrays where each struct key is a rule category and the array contains rule names to run.  Instead of an array, the value in the struct can also be the string `"*"` which will include all rules in that category
- **excludeRules** - Same format as includeRules but these rules are EXCLUDED from the final list.
- **ruleFiles** - Array of absolute or relative (to the JSON file) paths to JSON files containing an arary of structs defining rules to run
- **customRules** - An array of structs defining rules to run.

Here is an example `.codechecker.json` file:

```js
{
	"paths" : "**.cf?",
	"minSeverity" : 1,
	"includeRules" : {
		"Maintenance" : "*",
		"Security Risks - Best Practices" : "*",
		"One-off Rules" : "*",
		"Standards" : [
			"Don't use IS or GT for boolean tests"
		]
	},
	"excludeRules" : {
		"Maintenance" : [
			"Don't use Log"
		]
	},
	"ruleFiles" : [
		"myRules.json"
	],
	"customRules" : [
		{
			"pattern": "cfoutput",
			"message": "CFoutput is lame",
			"category": "One-off Rules",
			"name": "Don't use CFoutput",
			"extensions": "cfm,cfc",
			"severity": "3"
		}
	]
}
```

## View all Categories/Rules

To view all the categories and rules available to you, run this command:

```bash
codechecker categories
```
