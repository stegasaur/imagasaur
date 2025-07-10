import React, { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import axios from 'axios';
import './App.css';

interface UploadedFile {
  file: File;
  preview: string;
  status: 'uploading' | 'processing' | 'completed' | 'error';
  error?: string;
  thumbnailUrl?: string;
}

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3000';

function App() {
  const [files, setFiles] = useState<UploadedFile[]>([]);
  const [isUploading, setIsUploading] = useState(false);

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const newFiles = acceptedFiles.map(file => ({
      file,
      preview: URL.createObjectURL(file),
      status: 'uploading' as const,
    }));

    setFiles(prevFiles => [...prevFiles, ...newFiles]);
    
    // Upload each file
    newFiles.forEach(async (fileObj) => {
      try {
        const formData = new FormData();
        formData.append('file', fileObj.file);

        const response = await axios.post(`${API_BASE_URL}/upload`, formData, {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        });

        setFiles(prevFiles => 
          prevFiles.map(f => 
            f.file === fileObj.file 
              ? { 
                  ...f, 
                  status: 'completed' as const, 
                  thumbnailUrl: response.data.thumbnail_url 
                } 
              : f
          )
        );
      } catch (error) {
        console.error('Error uploading file:', error);
        setFiles(prevFiles => 
          prevFiles.map(f => 
            f.file === fileObj.file 
              ? { 
                  ...f, 
                  status: 'error' as const, 
                  error: 'Failed to upload file' 
                } 
              : f
          )
        );
      }
    });
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'image/*': []
    },
    disabled: isUploading,
  });

  const removeFile = (fileToRemove: File) => {
    setFiles(files.filter(file => file.file !== fileToRemove));
    // Revoke the data uri to avoid memory leaks
    URL.revokeObjectURL(fileToRemove.name);
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>Imagasaur</h1>
        <p>Upload images to generate thumbnails</p>
      </header>

      <main className="app-main">
        <div 
          {...getRootProps()} 
          className={`dropzone ${isDragActive ? 'active' : ''}`}
        >
          <input {...getInputProps()} />
          {isDragActive ? (
            <p>Drop the files here ...</p>
          ) : (
            <p>Drag 'n' drop some files here, or click to select files</p>
          )}
        </div>

        <div className="file-list">
          <h3>Uploaded Files</h3>
          {files.length === 0 ? (
            <p className="no-files">No files uploaded yet</p>
          ) : (
            <ul>
              {files.map((file, index) => (
                <li key={index} className="file-item">
                  <div className="file-preview">
                    <img 
                      src={file.preview} 
                      alt={file.file.name} 
                      className="thumbnail"
                    />
                    {file.thumbnailUrl && (
                      <img 
                        src={file.thumbnailUrl} 
                        alt={`${file.file.name} thumbnail`} 
                        className="thumbnail"
                      />
                    )}
                  </div>
                  <div className="file-info">
                    <p className="file-name">{file.file.name}</p>
                    <div className={`status ${file.status}`}>
                      {file.status === 'uploading' && 'Uploading...'}
                      {file.status === 'processing' && 'Processing...'}
                      {file.status === 'completed' && 'Completed'}
                      {file.status === 'error' && `Error: ${file.error}`}
                    </div>
                    <button 
                      className="remove-button" 
                      onClick={() => removeFile(file.file)}
                      disabled={file.status === 'uploading'}
                    >
                      Remove
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </main>

      <footer className="app-footer">
        <p>© {new Date().getFullYear()} Imagasaur - Serverless Image Processing</p>
      </footer>
    </div>
  );
}

export default App;
