import Vue from 'https://cdn.jsdelivr.net/npm/vue@2.6.14/dist/vue.esm.browser.js'

var vue = new Vue({
    el: '#app',
    data() {
        return {
            artist: {
                artistName: 'Pink Floyd'
            },
            years: [],
            albums: [],
            tracks: [],
            album_count: 0,
            track_count: 0,
            status_message: 'Loading is complete!'

        }
    },
    computed: {
        canCreate() {
            const result = this.artist.artistName.trim()
            console.log('canCreate:', result)
            return result
        }
    },
    methods: {
        async refreshYears() {
            console.log('msg:', "refreshYears")
            const db_content = await request('years')
            this.years = db_content.years
            this.album_count = db_content.album_count
            this.track_count = db_content.track_count
        },
        async createContent() {
            this.years = []
            this.albums = []
            this.tracks = []
            this.album_count = 0
            this.track_count = 0
            this.status_message = 'Please wait...'
            const {...artist} = this.artist
            this.artist.artistName = ''
            const result = await request('artist', 'POST', artist)
            console.log('createContent:', result)
            await this.refreshYears()
            this.status_message = 'Loading is complete!'
        },
        async updateContent(year) {
            console.log('updateContent:', year)
            const albums_and_tracks = await request(`content/${year}`)
            this.albums = albums_and_tracks.albums
            this.tracks = albums_and_tracks.tracks
        }
    },
    async mounted() {
        await this.refreshYears()
    }
})

async function request(url, method = 'GET', data = null) {
    try {
        const root_url = 'music_page/api/v1.0/' // use http://localhost:5000/music_page/api/v1.0/ for development
        const full_url = root_url + url
        const headers = {}
        let body
        if (data) {
            headers['Content-Type'] = 'application/json'
            body = JSON.stringify(data)
        }
        const response = await fetch(full_url, {
            method,
            headers,
            body
        })
        return await response.json()
    } catch (e) {
        console.warn('Error:', e.message)
    }
}
