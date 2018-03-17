project('com.github.davidmhewitt.vls', 'vala', 'c')

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

posix_dep = meson.get_compiler('vala').find_library('posix')

langserver_glib = subproject ('langserver-glib')
langserver_dep = langserver_glib.get_variable ('langserver_dep')

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
