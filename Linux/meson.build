project(
  'agentide',
  'c', 'vala',
  version: '0.1.0',
  meson_version: '>= 1.0.0',
  default_options: [
    'warning_level=2',
    'werror=false',
  ],
)

adwaita = dependency('libadwaita-1', version: '>= 1.4')
json_glib = dependency('json-glib-1.0')
vte = dependency('vte-2.91-gtk4', required: false)

vala_args = []
deps = [adwaita, json_glib]

if vte.found()
  vala_args += ['--define=HAVE_VTE']
  deps += [vte]
endif

executable(
  'agentide',
  'agentide.vala',
  dependencies: deps,
  vala_args: vala_args,
  install: true,
)
