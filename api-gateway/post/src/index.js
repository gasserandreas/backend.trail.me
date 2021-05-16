'use strict';

const PASSWORD = 'test';

exports.handler = function (event, _, callback) {
    const { body } = event;
    console.log(body);
    const { password } = JSON.parse(body);

    const valid = password === PASSWORD
    const statusCode = valid ? 200 : 403;

    var response = {
        statusCode,
        headers: {
            'Content-Type': 'application/json; charset=utf-8',
        },
        body: JSON.stringify({
            valid,
            data: 'data2',
        }),
    };
    callback(null, response);
};
