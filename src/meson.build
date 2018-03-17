code_files = files(
    'Application.vala',
    'CompileJob.vala',
    'ProjectManager.vala',
    'Reporter.vala',
    'Server.vala',
    'ValaFormatter.vala',
    'ProjectAnalyzers/AbstractProjectAnalyzer.vala',
    'ProjectAnalyzers/CMakeProjectAnalyzer.vala',
    'ProjectAnalyzers/MesonAnalyzer.vala',
    'ProjectAnalyzers/ValaProjectAnalyzer.vala'
)

executable(
    meson.project_name(),
    code_files,
    dependencies: [langserver_dep, dependencies],
    install: true,
)

linter_files = files(
    'linter/Application.vala',
    'ValaFormatter.vala'
)

executable(
    'com.github.davidmhewitt.vala-lint',
    linter_files,
    dependencies: dependencies
)
