import express from 'express';
import * as dotenv from 'dotenv';
import { v2 as cloudinary } from 'cloudinary';

import Post from '../mongodb/models/post.js'
//posts routes are going to be for creating a post and retrieving a post

dotenv.config(); // to make sure that our environment variables are getting populated

// now we have to write routes to be able to fetch and upload the images to activate the share with the community button

const router = express.Router(); // new instance of the router

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_SECRET,

})

router.route('/').get(async(req, res)=>{
    try{
        const posts = await Post.find({});
        res.status(200).json({success: true, data:posts})
    }
    catch(error){
        res.status(500).json({success: false, message: error})
    }
});

router.route('/').post(async(req, res)=> {
    try{
        const {name, prompt, photo } = req.body;
        const photoUrl = await cloudinary.uploader.upload(photo);

        const newPost = await Post.create({
            name,
            prompt,
            photo:photoUrl.url
        })
        res.status(201).json({success:true, data: newPost});
    }catch(error){
        res.status(500).json({success:false, message:error})
    }
})
export default router;