Pod::Spec.new do |s|
  s.name = 'FramePod'
  s.version = '2.0.0'
  s.summary = 'A framework pod with a resource bundle (isim test fixture).'
  s.homepage = 'https://example.invalid/FramePod'
  s.license = 'MIT'
  s.author = 'isim'
  s.source = { :path => '.' }
  s.ios.deployment_target = '17.0'
  s.source_files = 'Classes/**/*.{h,m}'
  s.resource_bundles = { 'FramePodResources' => ['Resources/*.txt'] }
end
