we will be using the tiago.dev firebase project

the database will be the default database in firestore
- however the database is currently shared with other projects, so make sure that the top most collection is called "match-chat" and that any database rules you create, must first check if the operation is in that collection

web app config details:

// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyAOJCxd1PY7JcsIc2z1KtCVZcDst4CtnFM",
  authDomain: "tiago-dev-site.firebaseapp.com",
  projectId: "tiago-dev-site",
  storageBucket: "tiago-dev-site.firebasestorage.app",
  messagingSenderId: "706177559293",
  appId: "1:706177559293:web:0e098fd3c81ad705d7ac94"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
