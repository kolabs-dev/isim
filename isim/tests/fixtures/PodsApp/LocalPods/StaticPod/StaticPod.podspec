Pod::Spec.new do |s|
  s.name = 'StaticPod'
  s.version = '1.4.0'
  s.summary = 'A static library pod (isim test fixture).'
  s.homepage = 'https://example.invalid/StaticPod'
  s.license = 'MIT'
  s.author = 'isim'
  s.source = { :path => '.' }
  s.ios.deployment_target = '17.0'
  s.source_files = 'Classes/**/*.{h,m}'
  s.resource_bundles = { 'StaticPodResources' => ['Resources/*.txt'] }
end
