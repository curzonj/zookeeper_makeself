include_recipe 'java'

remote_file "/opt/exhibitor.jar" do
  source "http://search.maven.org/remotecontent?filepath=com/netflix/exhibitor/exhibitor-standalone/1.5.0/exhibitor-standalone-1.5.0.jar"
end

ark 'zookeeper' do
  url "http://www.interior-dsgn.com/apache/zookeeper/zookeeper-3.4.5/zookeeper-3.4.5.tar.gz"
end
