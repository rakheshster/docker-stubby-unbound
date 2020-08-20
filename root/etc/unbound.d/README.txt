Any files added here with a .conf extension will be pulled in by Unbound. 

You can do `docker exec <container name> unbound-reload` to cause unbound to reload and pull in the changes. Or restart the container, but that will have downtime. 