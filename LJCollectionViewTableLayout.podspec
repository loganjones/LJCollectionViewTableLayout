Pod::Spec.new do |s|
  s.name = 'LJCollectionViewTableLayout'
  s.version = '1.0.0'
  s.summary = 'Table based layout (rows & columns) for UICollectionView'
  s.homepage = 'https://github.com/loganjones/LJCollectionViewTableLayout'
  s.license = {
    :type => 'MIT',
    :file => 'LICENSE'
  }
  s.author = 'Logan Jones', 'logan.b.jones@gmail.com'
  s.source = {
    :git => 'https://github.com/loganjones/LJCollectionViewTableLayout.git',
    :tag => s.version.to_s
  }
  s.platform = :ios, '6.0'
  s.source_files = 'Classes/'
  s.frameworks = 'UIKit'
  s.requires_arc = true
end
