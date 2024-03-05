Pod::Spec.new do |s|
  s.name             = 'Regex'
  s.version          = '0.0.1'
  s.summary          = 'Open source regex engine with hitEnd.'
  s.description      = <<-DESC
  Open source regex engine with hitEnd.
  hitEnd returns true if the end of input was hit by the search engine in the last match operation performed by the Matcher.
  When this method returns true, then it is possible that more input would have changed the result of the last search.
                       DESC
  s.homepage         = 'https://github.com/alekseishirokov/Regex'
  s.license          = 'MIT'
  s.authors          = { 'Aleksei Shirokov' => 'avshirokov@gmail.com' }
  s.source           = { :git => 'https://github.com/alekseishirokov/Regex.git', :tag => s.version.to_s }
  s.source_files     = 'Source/*'
  s.ios.deployment_target = '12.0'
end
