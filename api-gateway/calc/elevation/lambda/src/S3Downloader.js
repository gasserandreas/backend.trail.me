import AWS from 'aws-sdk';
import { createWriteStream } from 'fs';


/**
 * S3 downloader for TileSet object
 * inspired by imagino downloader: https://github.com/perliedman/node-hgt/blob/master/src/imagico.js
 */
function S3Downloader(cacheDir, s3Bucket, options) {
  const { awsConfig } = options;

  /**
   * update AWS config if passed in
   */
  if (awsConfig) {
    AWS.config.update(awsConfig);
  }

  this._cacheDir = cacheDir;
  this._s3Bucket = s3Bucket;
  this.options = { ...options };
  this._downloads = {};
}

S3Downloader.prototype.download = function(tileKey, latLng, cb) {
  let download = this._downloads[tileKey];

  const cleanup = function() {
    delete this._downloads[tileKey];
  }.bind(this);

  if (!download) {
    const filename = this.getFileName(latLng);

    download = this.loadFileFromS3(filename)
      .then((stream) => this.writeFileStream(stream, filename))
      .then(cleanup)
  
    this._downloads[tileKey] = download;
  }

  download.then(function() {
    cb(undefined);
  }).catch(function(err) {
    cb(err);
  });
}

S3Downloader.prototype.loadFileFromS3 = function(filename) {
  return new Promise((resolve, reject) => {
    const s3 = new AWS.S3();
    const params = {
      Bucket: this._s3Bucket,
      Key: filename,
    };

    /**
     * load object from s3
     */
    try {
      const stream = s3.getObject(params).createReadStream();
      resolve(stream);
    } catch (error) {
      console.log(err, err.stack);
      reject(error);
    }
  });
}

S3Downloader.prototype.writeFileStream = function(stream, filename) {
  return new Promise((resolve) => {
    stream.pipe(createWriteStream(`${this._cacheDir}/${filename}`));

    stream.on('end', () => resolve());
  });
}

S3Downloader.prototype.getFileName = function(coordinate) {
  try {
    const { lat, lng } = coordinate;
    const n = String(lat).split('.')[0];
    const rawE = String(lng).split('.')[0];

    const e = parseInt(rawE) < 10 ? `00${rawE}` : `0${rawE}`;
    return(`N${n}E${e}.hgt`);
  } catch (error) {
    return(null);
  }
}

export default S3Downloader;
