import express from 'express';
import * as dotenv from 'dotenv';
//api from openapi
import {Configuration, OpenAIApi} from 'openai'

import Post from '../mongodb/models/post.js'
//dall e routes are going to be used to generate the data using the open ai api

dotenv.config(); // to make sure that our environment variables are getting populated
// to connect with the api we are going to need an api key 

const router = express.Router(); // new instance of the router
const configuration = new Configuration({
    apikey : process.env.OPEN_AI_KEY,
})

const openai = new OpenAIApi(configuration);

router.route('/').get((req,res)=> {
    res.send('hello from Dall-E!');
})

router.route('/').post(async(req, res)=>
{
    try {
        const {prompt} = req.body;

        const aiResponse = await openai.createImage({
            prompt,
            n:1,
            size: '1024x1024',
            response_format:'b64_json',
        });

        const image = aiResponse.data.data[0].b64_json;
        res.status(200).json({ photo: image });
    }catch(error){
        console.log(error);
        res.status(500).send(error?.response.data.error.message)
    
    }
    })



export default router;