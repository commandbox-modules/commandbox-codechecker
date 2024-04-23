component {
	any function format(required array results, filesystemUtil) {
		var categoryMap = {
			'Case Sensitive Functions - Best Practices': ['Compatibility'],
			'Formatting Functions - Best Practices': ['Style'],
			'Maintenance': ['Complexity', 'Clarity'],
			'Performance': ['Performance'],
			'QueryParamScanner': ['Security'],
			'Security Risks - Best Practices': ['Security'],
			'Standards': ['Clarity'],
			'VarScoper': ['Performance', 'Security'],
		}
		var severityLabel=['info', 'minor', 'major', 'critical', 'blocker'];
		return results.map(function(result) {
			return {
				'type': 'issue',
				'description': result.message,
				'check_name': result.rule,
				'severity': severityLabel[result.severity],
				'categories': (categoryMap[result.category]?:[result.category]),
				'location': {
					'path': replace(result.directory & result.file, filesystemUtil.resolvePath(''), ''),
					'lines': {
						'begin': result.lineNumber
					} 
				}
			};
		} );
	}
}
