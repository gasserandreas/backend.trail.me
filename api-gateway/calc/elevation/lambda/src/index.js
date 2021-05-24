'use strict';

import fs from 'fs';
import { TileSet } from './node-hgt';

import S3Downloader from './S3Downloader';

const BUCKET = '151434533289-calc-elevation-assets-bucket';

const CACHE_DIR = '/tmp/';
const MAX_ITEM = 20;

exports.handler = function (event, _, callback) {
    try {
      let statusCode = 200;
      let errorMessage;

      const { body } = event;
      const coordinates = JSON.parse(body);

      if (!body || !coordinates) {
        errorMessage = 'Wrong or invalid body payload specified';
        statusCode = 400;
        callback(null, { statusCode, body: errorMessage });
      }

      if (coordinates.length > MAX_ITEM) {
        errorMessage = 'Too many coordinates specified in payload';
        statusCode = 400;
        callback(null, { statusCode, body: errorMessage });
      }

      /**
       * create dir if not yet created
       */
      if (!fs.existsSync(CACHE_DIR)) {
        fs.mkdirSync(CACHE_DIR);
      }

      /**
       * use custom downloader
       */
      const downloader = new S3Downloader(CACHE_DIR, BUCKET, {});
      const tileset = new TileSet(CACHE_DIR, { downloader });

      /**
       * calculate elevation for coordinates
       */
      Promise.all(
        coordinates.map(
          (coordinate) => new Promise((resolve) => {
            const { lat, lng } = coordinate;
            /**
             * get elevation data for coordinate
             */
            tileset.getElevation([lat, lng], function(err, elevation) {
              if (err) {
                reject(err);
              } else {
                resolve(elevation);
              }
            });
          })
        )
      ).then((elevations) => {
        /**
         * create new coordinates data
         */
        const newCoordinates = coordinates.map((coordinate, i) => {
          const elevation = elevations[i];
          return {
            ...coordinate,
            elevation,
          };
        }); 

        /**
         * create lambda response and add data
         */
        const response = {
          statusCode: 200,
          headers: {
              'Content-Type': 'application/json; charset=utf-8',
          },
          body: JSON.stringify(newCoordinates),
        };

        callback(null, response);
      }).catch((error) => {
        callback(error.message);
      })
    } catch (error) {
      callback(error.message);
    };
};