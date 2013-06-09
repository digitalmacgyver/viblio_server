import urllib, urllib2, cookielib

url = "http://localhost:3000/services/na/authenticate"
form_data = {'email' : 'aqpeeb@gmail.com', 
             'password' : 'password',
             'realm': 'db'}

jar = cookielib.CookieJar()
opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(jar))
form_data = urllib.urlencode(form_data)
resp = opener.open(url, form_data)
print resp.read()
