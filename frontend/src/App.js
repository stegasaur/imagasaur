import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useDropzone } from 'react-dropzone';
import './App.css';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

function App() {
  const [images, setImages] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Load images on component mount
  useEffect(() => {
    loadImages();
  }, []);

  const loadImages = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/images`);
      if (response.data.success) {
        setImages(response.data.images);
      }
    } catch (error) {
      console.error('Error loading images:', error);
      setError('Failed to load images');
    }
  };

  const onDrop = async (acceptedFiles) => {
    if (acceptedFiles.length === 0) return;

    const file = acceptedFiles[0];
    setUploading(true);
    setError('');
    setSuccess('');
    setUploadProgress(0);

    // Validate file size (10MB)
    const maxSize = 10 * 1024 * 1024; // 10MB in bytes
    if (file.size > maxSize) {
      setError('File size must be less than 10MB');
      setUploading(false);
      return;
    }

    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/bmp', 'image/tiff', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
      setError('Please select a valid image file (JPEG, PNG, GIF, BMP, TIFF, or WebP)');
      setUploading(false);
      return;
    }

    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await axios.post(`${API_BASE_URL}/upload`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        onUploadProgress: (progressEvent) => {
          const progress = Math.round((progressEvent.loaded * 100) / progressEvent.total);
          setUploadProgress(progress);
        },
      });

      if (response.data.success) {
        setSuccess('Image uploaded successfully! Processing thumbnail...');
        setUploadProgress(100);

        // Poll for the processed image
        pollForProcessedImage(response.data.s3_key);
      } else {
        setError(response.data.message || 'Upload failed');
      }
    } catch (error) {
      console.error('Upload error:', error);
      const errorMessage = error.response?.data?.message || 'Upload failed. Please try again.';
      setError(errorMessage);
    } finally {
      setUploading(false);
      setUploadProgress(0);
    }
  };

  const pollForProcessedImage = async (originalKey) => {
    const maxAttempts = 30; // 30 seconds
    let attempts = 0;

    const poll = async () => {
      try {
        // Extract the filename from the original key
        const filename = originalKey.split('/').pop();
        const name = filename.split('.')[0];
        const thumbnailKey = `processed/${name}_thumbnail.jpg`;

        const response = await axios.get(`${API_BASE_URL}/image/${thumbnailKey}`);

        if (response.data.success) {
          setSuccess('Thumbnail created successfully!');
          loadImages(); // Refresh the image list
          return;
        }
      } catch (error) {
        // Image not ready yet, continue polling
      }

      attempts++;
      if (attempts < maxAttempts) {
        setTimeout(poll, 1000); // Poll every second
      } else {
        setError('Processing timeout. The thumbnail may still be processing.');
      }
    };

    poll();
  };

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'image/*': ['.jpeg', '.jpg', '.png', '.gif', '.bmp', '.tiff', '.webp']
    },
    multiple: false,
    disabled: uploading
  });

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleString();
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Imagasaur</h1>
        <p>Upload images and get 100x100 thumbnails automatically</p>
      </header>

      <main className="App-main">
        {/* Upload Section */}
        <section className="upload-section">
          <h2>Upload Image</h2>
          <div
            {...getRootProps()}
            className={`dropzone ${isDragActive ? 'active' : ''} ${uploading ? 'uploading' : ''}`}
          >
            <input {...getInputProps()} />
            {uploading ? (
              <div className="upload-progress">
                <div className="progress-bar">
                  <div
                    className="progress-fill"
                    style={{ width: `${uploadProgress}%` }}
                  ></div>
                </div>
                <p>Uploading... {uploadProgress}%</p>
              </div>
            ) : (
              <div className="dropzone-content">
                <div className="upload-icon">📁</div>
                {isDragActive ? (
                  <p>Drop the image here...</p>
                ) : (
                  <div>
                    <p>Drag & drop an image here, or click to select</p>
                    <p className="file-info">
                      Supported formats: JPEG, PNG, GIF, BMP, TIFF, WebP<br />
                      Maximum size: 10MB
                    </p>
                  </div>
                )}
              </div>
            )}
          </div>
        </section>

        {/* Messages */}
        {error && (
          <div className="message error">
            <span className="message-icon">⚠️</span>
            {error}
          </div>
        )}
        {success && (
          <div className="message success">
            <span className="message-icon">✅</span>
            {success}
          </div>
        )}

        {/* Images Section */}
        <section className="images-section">
          <h2>Processed Thumbnails ({images.length})</h2>
          {images.length === 0 ? (
            <div className="no-images">
              <p>No processed images yet. Upload an image to get started!</p>
            </div>
          ) : (
            <div className="images-grid">
              {images.map((image, index) => (
                <div key={index} className="image-card">
                  <div className="image-container">
                    <img
                      src={image.url}
                      alt="Thumbnail"
                      className="thumbnail"
                      onError={(e) => {
                        e.target.style.display = 'none';
                        e.target.nextSibling.style.display = 'block';
                      }}
                    />
                    <div className="image-error" style={{ display: 'none' }}>
                      <span>Image unavailable</span>
                    </div>
                  </div>
                  <div className="image-info">
                    <p className="image-name">{image.key.split('/').pop()}</p>
                    <p className="image-size">{formatFileSize(image.size)}</p>
                    <p className="image-date">{formatDate(image.last_modified)}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </main>

      <footer className="App-footer">
        <p>Imagasaur - Image Processing Application</p>
      </footer>
    </div>
  );
}

export default App;
