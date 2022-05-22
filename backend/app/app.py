from flask import jsonify, Flask
from flask_restful import Api, Resource, reqparse
from flask_cors import CORS
import sqlalchemy
import requests
import logging

import concurrent.futures
from dateutil import parser
from sqlalchemy import extract, cast, nullslast, exc
from sqlalchemy.ext.hybrid import hybrid_property
from flask_sqlalchemy import SQLAlchemy
import os
from dotenv import load_dotenv
from flask_migrate import Migrate
from flask_wtf.csrf import CSRFProtect

url1 = "https://itunes.apple.com/search"
url2 = "https://itunes.apple.com/lookup"
db_error1 = 'Error while accessing the DB'
db_error2 = 'Error with DB'
limit = 200  # The number of search results
app = Flask(__name__)
api = Api(app)
CORS(app, resources={r"/*": {"origins": "*", "send_wildcard": "False"}})  # Compliant

load_dotenv()
DB_USER = str(os.environ.get("DB_USER"))
DB_PASSWORD = str(os.environ.get("DB_PASSWORD"))
DB_NAME = str(os.environ.get("DB_NAME"))
DB_HOST = str(os.environ.get("SERVICE_DB_SERVICE_HOST"))

app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://' + DB_USER + ':' + DB_PASSWORD + '@' + \
                                        DB_HOST + ':5432/' + DB_NAME
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
migrate = Migrate(app, db)


# Database model
class Album(db.Model):
    __tablename__ = 'albums'
    artistId = db.Column(db.Integer)
    collectionId = db.Column(db.Integer, primary_key=True)
    collectionName = db.Column(db.String(300))
    collectionPrice = db.Column(db.Float)
    trackCount = db.Column(db.Integer)
    releaseDate = db.Column(db.DateTime)
    primaryGenreName = db.Column(db.String(50))

    @hybrid_property
    def date_year(self):
        return self.releaseDate.year

    @date_year.expression
    def date_year(self):
        return extract('year', self.releaseDate)

    def __repr__(self):
        return '<Album %r>' % self.collectionId


class Track(db.Model):
    __tablename__ = 'tracks'
    wrapperType = db.Column(db.String(20))
    kind = db.Column(db.String(20))
    artistId = db.Column(db.Integer)
    collectionId = db.Column(db.Integer)  # Foreign key
    trackId = db.Column(db.Integer, primary_key=True)
    artistName = db.Column(db.String(100), nullable=False)
    collectionPrice = db.Column(db.Float)
    trackName = db.Column(db.String(300))
    trackPrice = db.Column(db.Float)
    releaseDate = db.Column(db.DateTime)
    trackCount = db.Column(db.Integer)
    trackNumber = db.Column(db.Integer)
    primaryGenreName = db.Column(db.String(50))

    @hybrid_property
    def date_year(self):
        return self.releaseDate.year

    @date_year.expression
    def date_year(self):
        return extract('year', self.releaseDate)

    @hybrid_property
    def collection_name_null(self):
        return None

    @collection_name_null.expression
    def collection_name_null(self):
        return cast(None, sqlalchemy.String)

    def __repr__(self):
        return '<Track %r>' % self.trackId


# Clean DB
def clean_db():
    try:
        db.session.query(Album).delete()
        db.session.query(Track).delete()
        db.session.commit()
    except exc.SQLAlchemyError:
        logging.exception(db_error1)
        raise
    except:
        logging.exception(db_error2)
        raise


# Search and return artistID
def search(term):
    payload = {"term": term, "entity": "allArtist", "attribute": "allArtistTerm", "limit": "1"}
    try:
        # Return artistId of 1st artist
        artist_id = requests.get(url1, params=payload).json().get("results", [])[0]["artistId"]
    except ConnectionError:
        logging.exception('Error itunes search')
        raise
    except:
        logging.exception('Error parsing itunes search')
        raise
    return artist_id


# Lookup from iTunes
def lookup(lookup_id, entity):
    payload = {"id": lookup_id, "entity": entity, "limit": limit}
    try:
        tracks = requests.get(url2, params=payload).json().get("results", [])  # json
    except ConnectionError:
        logging.exception('Error itunes lookup')
        raise
    except:
        logging.exception('Error parsing itunes lookup')
        raise
    return tracks


# Save record about an album into the DB, table Album
def save_album(album):  # from json
    if album["wrapperType"] == "collection":
        album_row = Album()  # table row
        for i in "artistId", "collectionId", "collectionName", "collectionPrice", "trackCount", "primaryGenreName":
            setattr(album_row, i, album[i] if i in album else None)
        album_row.releaseDate = parser.parse(album["releaseDate"])
        try:
            db.session.add(album_row)
            db.session.commit()
        except exc.SQLAlchemyError:
            logging.exception(db_error1)
            raise
        except:
            logging.exception(db_error2)
            raise


# Save record about a track into the DB, table Track
def save_item(item):  # from json
    if "kind" in item:
        item_row = Track()  # table row
        for i in "wrapperType", "kind", "artistId", "collectionId", "trackId", "artistName", "collectionPrice", \
                 "trackName", "trackPrice", "trackCount", "trackNumber", "primaryGenreName":
            setattr(item_row, i, item[i] if i in item else None)
        item_row.releaseDate = parser.parse(item["releaseDate"])
        try:
            db.session.add(item_row)
            db.session.commit()
        except exc.SQLAlchemyError:
            logging.exception(db_error1)
            raise
        except:
            logging.exception(db_error2)
            raise


# Do long operations with album (saves album in Album table, requests songs, saves song in DB)
def album_processing(album):  # from json
    save_album(album)
    for song in lookup(album["collectionId"], "song"):
        save_item(song)


# Lookup and save musicVideo, ebook into DB
def item_lookup_save(artist_id):  # from json
    for item in lookup(artist_id, "musicVideo,ebook,mix"):  # Lookup musicVideo, ebook
        if "collectionId" not in item:  # Only if album is not present. Tracks from albums are already saved.
            save_item(item)  # Save musicVideo, ebook in DB


class ContentAPI(Resource):
    #  curl -i http://localhost:5000/music_page/api/v1.0/content/2014
    @staticmethod
    def get(year):
        albums_json = Album.query.filter(Album.date_year == year).order_by(
            nullslast(Album.collectionPrice.desc())).all()
        albums_dict = []
        for album in albums_json:
            albums_dict.append({
                'artistId': album.artistId,
                'collectionId': album.collectionId,
                'collectionName': album.collectionName,
                'collectionPrice': album.collectionPrice,
                'trackCount': album.trackCount,
                'releaseDate': album.releaseDate,
                'primaryGenreName': album.primaryGenreName,
            })
        # Tracks which are on the albums
        tracks1 = Track.query.join(Album, Track.collectionId == Album.collectionId).add_columns(
            Track.wrapperType, Track.kind, Track.artistId, Track.collectionId, Track.trackId,
            Track.artistName, Track.trackName, Track.collectionPrice, Track.trackPrice,
            Track.releaseDate, Track.trackCount, Track.trackNumber, Track.primaryGenreName,
            Album.collectionName.label('collectionName')).filter(Track.date_year == year)
        # Tracks which are not on the albums
        tracks2 = Track.query.add_columns(
            Track.wrapperType, Track.kind, Track.artistId, Track.collectionId, Track.trackId,
            Track.artistName, Track.trackName, Track.collectionPrice, Track.trackPrice,
            Track.releaseDate, Track.trackCount, Track.trackNumber, Track.primaryGenreName,
            Track.collection_name_null.label('collectionName')).filter(Track.collectionId.is_(None)).filter(
            Track.date_year == year)
        all_tracks = tracks1.union(tracks2).order_by(nullslast(Track.trackPrice.desc())).all()
        tracks_dict = []
        for track in all_tracks:
            tracks_dict.append({
                'wrapperType': track.wrapperType,
                'kind': track.kind,
                'artistId': track.artistId,
                'collectionId': track.collectionId,
                'trackId': track.trackId,
                'artistName': track.artistName,
                'trackName': track.trackName,
                'collectionPrice': track.collectionPrice,
                'trackPrice': track.trackPrice,
                'releaseDate': track.releaseDate,
                'trackCount': track.trackCount,
                'trackNumber': track.trackNumber,
                'primaryGenreName': track.primaryGenreName,
                'collectionName': track.collectionName
            })
        return jsonify({'albums': albums_dict, 'tracks': tracks_dict})

# http://localhost:5000/music_page/api/v1.0/years
class YearsAPI(Resource):
    @staticmethod
    def get():
        list1 = Album.query.with_entities(Album.date_year.label('year'))
        list2 = Track.query.with_entities(Track.date_year.label('year'))
        list_all_years = list1.union(list2).order_by('year').all()
        year_dict = []
        for year in list_all_years:
            year_dict.append(dict(zip(['year'], year)))
        list_my = jsonify({'years': year_dict, 'album_count': db.session.query(Album).count(),
                           'track_count': db.session.query(Track).count()})
        return list_my


class ArtistNameAPI(Resource):
    def __init__(self):
        self.reqparse = reqparse.RequestParser()
        self.reqparse.add_argument('artistName', type=str, required=True,
                                   help='artist Name',
                                   location='json')
        super(ArtistNameAPI, self).__init__()

    # curl -i -H "Content-Type: application/json" -X POST -d '{"artistName":"Pink Floyd"}'
    # http://localhost:5000/music_page/api/v1.0/artist
    def post(self):
        args = self.reqparse.parse_args()
        max_workers = 70
        clean_db()
        artist_id = search(args['artistName'])  # search artistId from artist Name typed in the form
        albums_json = lookup(artist_id, "album")  # lookup albums of this artist
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(album_processing, album)
                       for album in albums_json
                       if album["wrapperType"] == "collection"]
            futures.append(executor.submit(item_lookup_save, artist_id))
            # for future in concurrent.futures.as_completed(futures):
            #     pass
        return artist_id


api.add_resource(ArtistNameAPI, '/music_page/api/v1.0/artist', endpoint='artist')
api.add_resource(YearsAPI, '/music_page/api/v1.0/years', endpoint='years')
api.add_resource(ContentAPI, '/music_page/api/v1.0/content/<int:year>', endpoint='tracks_for_year')


def main():
    app.run(debug=False, host='0.0.0.0')


if __name__ == '__main__':
    main()

# pip freeze > requirements.txt
# docker build -t music_page_db_img --build-arg POSTGRES_USER=db_user --build-arg POSTGRES_PASSWORD=db_pass_123 --build-arg POSTGRES_DB=db_music_page .
# docker run -d -p 5432:5432 --name diploma_db music_page_db_img

# flask db init
# flask db migrate -m "Initial migration."
# flask db upgrade

# docker exec -it music_page_db sh
# psql -U db_user -d db_music_page
# \dt;
