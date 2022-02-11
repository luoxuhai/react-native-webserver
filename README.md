# react-native-webserver

## Install

```shell
npm install --save @react-native-library/webserver
```

## Automatically link

#### With React Native 0.27+

```shell
react-native link @react-native-library/webserver
```

## Example

First import @react-native-library/webserver:

```js
import { HttpServer } from "@react-native-library/webserver";
```

Initalize the server in the `componentWillMount` lifecycle method. You need to provide a `port` and a callback.

```js

    componentWillMount() {
      // initalize the server (now accessible via localhost:1234)
      HttpServer.start(5561, 'http_service' (request, response) => {

          // you can use request.url, request.type and request.postData here
          if (request.method === "GET" && request.url.startsWith('/users')) {
            response.send(200, "application/json", "{\"message\": \"OK\"}");
          } else if (request.method === "GET" && request.url.startsWith('/image.jpg')) {
            response.sendFile('xxx/xxx.jpg');
          } else {
            response.send(400, "application/json", "{\"message\": \"Bad Request\"}");
          }

      });
    }

```

Finally, ensure that you disable the server when your component is being unmounted.

```js

  componentWillUnmount() {
    HttpServer.stop();
  }

```
