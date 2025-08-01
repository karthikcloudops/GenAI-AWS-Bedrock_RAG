// Configuration
const API_ENDPOINT = 'https://xsrcqk2io6.execute-api.ap-southeast-2.amazonaws.com/prod/query';

// DOM Elements
const fileInput = document.getElementById('fileInput');
const uploadProgress = document.getElementById('uploadProgress');
const progressBar = document.getElementById('progressBar');
const progressText = document.getElementById('progressText');
const uploadStatus = document.getElementById('uploadStatus');
const chatMessages = document.getElementById('chatMessages');
const messageInput = document.getElementById('messageInput');
const sendButton = document.getElementById('sendButton');
const typingIndicator = document.getElementById('typingIndicator');
const chatHistory = document.getElementById('chatHistory');
const clearHistory = document.getElementById('clearHistory');

// Chat history storage
let chatHistoryData = JSON.parse(localStorage.getItem('chatHistory') || '[]');

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    updateChatHistoryDisplay();
    setupEventListeners();
});

function setupEventListeners() {
    // File upload
    fileInput.addEventListener('change', handleFileUpload);
    
    // Send message
    sendButton.addEventListener('click', sendMessage);
    messageInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            sendMessage();
        }
    });
    
    // Clear history
    clearHistory.addEventListener('click', clearChatHistory);
}

async function handleFileUpload(event) {
    const files = event.target.files;
    if (files.length === 0) return;
    
    showUploadProgress();
    
    for (let i = 0; i < files.length; i++) {
        const file = files[i];
        const progress = ((i + 1) / files.length) * 100;
        
        updateProgress(progress, `Uploading ${file.name}...`);
        
        try {
            await uploadFile(file);
        } catch (error) {
            console.error('Upload failed:', error);
            showUploadError(`Failed to upload ${file.name}`);
        }
    }
    
    hideUploadProgress();
    showUploadSuccess();
    
    // Clear the file input
    fileInput.value = '';
}

async function uploadFile(file) {
    // For now, we'll simulate file upload since we need to implement the actual upload endpoint
    // In a real implementation, you would upload to S3 or your backend
    return new Promise((resolve) => {
        setTimeout(resolve, 1000); // Simulate upload time
    });
}

function showUploadProgress() {
    uploadProgress.classList.remove('hidden');
    uploadStatus.classList.add('hidden');
}

function hideUploadProgress() {
    uploadProgress.classList.add('hidden');
}

function updateProgress(percentage, text) {
    progressBar.style.width = `${percentage}%`;
    progressText.textContent = text;
}

function showUploadSuccess() {
    uploadStatus.classList.remove('hidden');
    setTimeout(() => {
        uploadStatus.classList.add('hidden');
    }, 3000);
}

function showUploadError(message) {
    // Implementation for showing upload errors
    console.error(message);
}

async function sendMessage() {
    const message = messageInput.value.trim();
    if (!message) return;
    
    // Add user message to chat
    addMessageToChat('user', message);
    
    // Clear input
    messageInput.value = '';
    
    // Show typing indicator
    showTypingIndicator();
    
    try {
        // Send message to API
        const response = await fetch(API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ query: message })
        });
        
        const data = await response.json();
        
        // Hide typing indicator
        hideTypingIndicator();
        
        if (response.ok) {
            // Add AI response to chat
            addMessageToChat('ai', data.response || data.message || 'I received your message but couldn\'t process it properly.');
        } else {
            // Handle error
            addMessageToChat('ai', `Error: ${data.message || 'Failed to get response from AI'}`);
        }
        
        // Save to chat history
        saveToChatHistory(message, data.response || data.message || 'Error occurred');
        
    } catch (error) {
        console.error('Error sending message:', error);
        hideTypingIndicator();
        addMessageToChat('ai', 'Sorry, I encountered an error while processing your request. Please try again.');
    }
}

function addMessageToChat(sender, message) {
    const messageDiv = document.createElement('div');
    messageDiv.className = 'flex items-start space-x-3';
    
    const iconDiv = document.createElement('div');
    iconDiv.className = sender === 'user' ? 'bg-green-100 rounded-full p-2' : 'bg-blue-100 rounded-full p-2';
    
    const icon = document.createElement('i');
    icon.className = sender === 'user' ? 'fas fa-user text-green-600' : 'fas fa-robot text-blue-600';
    iconDiv.appendChild(icon);
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'flex-1';
    
    const messageContent = document.createElement('div');
    messageContent.className = sender === 'user' ? 'bg-green-50 rounded-lg p-3' : 'bg-blue-50 rounded-lg p-3';
    messageContent.innerHTML = `<p class="text-gray-800">${escapeHtml(message)}</p>`;
    
    const timestamp = document.createElement('p');
    timestamp.className = 'text-xs text-gray-500 mt-1';
    timestamp.textContent = new Date().toLocaleTimeString();
    
    contentDiv.appendChild(messageContent);
    contentDiv.appendChild(timestamp);
    
    messageDiv.appendChild(iconDiv);
    messageDiv.appendChild(contentDiv);
    
    chatMessages.appendChild(messageDiv);
    
    // Scroll to bottom
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showTypingIndicator() {
    typingIndicator.classList.remove('hidden');
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function hideTypingIndicator() {
    typingIndicator.classList.add('hidden');
}

function saveToChatHistory(question, answer) {
    const chatEntry = {
        id: Date.now(),
        question,
        answer,
        timestamp: new Date().toISOString()
    };
    
    chatHistoryData.unshift(chatEntry);
    
    // Keep only last 10 conversations
    if (chatHistoryData.length > 10) {
        chatHistoryData = chatHistoryData.slice(0, 10);
    }
    
    localStorage.setItem('chatHistory', JSON.stringify(chatHistoryData));
    updateChatHistoryDisplay();
}

function updateChatHistoryDisplay() {
    if (chatHistoryData.length === 0) {
        chatHistory.innerHTML = '<p class="text-gray-500 text-sm text-center">No chat history yet</p>';
        return;
    }
    
    chatHistory.innerHTML = '';
    
    chatHistoryData.forEach(entry => {
        const historyItem = document.createElement('div');
        historyItem.className = 'p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors';
        
        const question = document.createElement('p');
        question.className = 'text-sm font-medium text-gray-800 truncate';
        question.textContent = entry.question;
        
        const timestamp = document.createElement('p');
        timestamp.className = 'text-xs text-gray-500 mt-1';
        timestamp.textContent = new Date(entry.timestamp).toLocaleDateString();
        
        historyItem.appendChild(question);
        historyItem.appendChild(timestamp);
        
        // Click to load conversation
        historyItem.addEventListener('click', () => {
            loadConversation(entry);
        });
        
        chatHistory.appendChild(historyItem);
    });
}

function loadConversation(entry) {
    // Clear current chat
    chatMessages.innerHTML = '';
    
    // Add the conversation
    addMessageToChat('user', entry.question);
    addMessageToChat('ai', entry.answer);
}

function clearChatHistory() {
    if (confirm('Are you sure you want to clear all chat history?')) {
        chatHistoryData = [];
        localStorage.removeItem('chatHistory');
        updateChatHistoryDisplay();
        
        // Clear current chat
        chatMessages.innerHTML = '';
        
        // Add welcome message
        addMessageToChat('ai', 'Hello! I\'m your AI assistant. I can help you find information from your uploaded documents. Ask me anything!');
    }
} 