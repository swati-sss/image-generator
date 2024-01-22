import express from 'express';
import * as dotenv from 'dotenv';
import cors from 'cors';
import connectDB from './mongodb/connect.js';
import postRoutes from './routes/postRoutes.js'
import Dalleroutes from './routes/Dalleroutes.js'


dotenv.config();

const app = express() /* creates a express app*/
app.use(cors());
app.use(express.json({limit: '50mb' }));
app.use('/api/v1/post', postRoutes) //comment- APi endpoints for posting and accessing 
app.use('/api/v1/dalle', Dalleroutes)
app.get('/', async (req, res) => {
    res.send('Hello from Dall-E');

})

const startServer = async () =>{
    try {
        connectDB(process.env.MONGO_DB_URL);
        app.listen(3001, ()=> console.log('server has started on the port http://localhost:3001'))

    } catch(error){
        console.log(err);
    }
}
    

startServer()