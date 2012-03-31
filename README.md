# Description
- - -
[Imageshack](http://www.imageshack.us) decided to force users to migrate to [imgur](http://imgur.com) by threatening to delete their images. This script will make it possible to dump all imageshack images from an user's account.

# Usage
- - -
`ruby main.rb [options]`

Available options:
1. `-u=[username]` - username, *mandatory* (if not supplied, user will be prompted do that from stdin)
2. `-p=[password]` - password, *mandatory* (if not supplied, user will be prompted do that from stdin)
3. `-t=[number]` - number of threads used for concurrent downloads, optional (default 12)
4. `-d=[path]` - directory where the images will be downloaded (default: imageshack-dump in current working directory)
