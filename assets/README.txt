ALL FILES IN THIS FOLDER CAN BE IGNORED

But here's what we have if you are curious ... 

* stubby.yml is configured with my NextDNS upstream. I copy this over to my running container to override the defaults. 
  * I wanted the container to work out of the box with generic privacy DNS servers, which is why I go this route to separating my config preferences out. 

* xx_stubby.yml is similar to the above but I use separate endpoints to identify my devices to NextDNS. 

Here's how I copy the file over to my running container:

docker cp assets/pi1_stubby.yml pi1_stubby-dnsmasq:/etc/stubby/stubby.yml
