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

executable(
  'agentide',
  'agentide.vala',
  dependencies: [adwaita],
  install: true,
)
