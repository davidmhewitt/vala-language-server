project('com.github.davidmhewitt.vls', 'vala', 'c')

# Prefer vala 0.42 for now, which is currently unreleased, as it should contain
# a fix for a memory leak (https://bugzilla.gnome.org/show_bug.cgi?id=794979)
vala_dep = dependency('libvala-0.42', required: false)
if vala_dep.found ()
    add_project_arguments('--define=HAVE_LIBVALA_042', language : 'vala')
else
    # We need libvala-X.XX library, but it changes depending on the version that is installed
    # Plus development versions are odd numbers registered as even
    vala_versions = meson.get_compiler('vala').version().split('.')
    vala_major = vala_versions[0]
    vala_minor_int = vala_versions[1].to_int()
    if vala_minor_int.is_odd()
        vala_minor_int = vala_minor_int + 1
    endif

    vala_name = 'libvala-@0@.@1@'.format(vala_major, vala_minor_int)
    vala_dep = dependency(vala_name)
endif

posix_dep = meson.get_compiler('vala').find_library('posix')

langserver_dep = dependency('langserver-glib', fallback : ['langserver-glib', 'langserver_dep'])

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-unix-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
    dependency('jsonrpc-glib-1.0'),
    vala_dep,
    posix_dep,
]

subdir ('src')
