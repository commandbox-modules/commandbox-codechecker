component {
    any function format(required array results) {
        var severityLabel=['info', 'minor', 'major', 'critical', 'blocker'];
        return results.map(function(result) {
            return {
                'type': 'issue',
                'description': result.message,
                'check_name': result.rule,
                'severity': severityLabel[result.severity],
                'categories': [
                    result.category, // FIXME: Use lookup map to use supported names
                ],
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
