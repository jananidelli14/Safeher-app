import axios from 'axios';

const API_BASE_URL = 'http://localhost:5000/api';

export const activateSOS = async (userId, location, emergencyContacts) => {
  try {
    const response = await axios.post(`${API_BASE_URL}/sos/activate`, {
      user_id: userId,
      location: location,
      emergency_contacts: emergencyContacts
    });
    return response.data;
  } catch (error) {
    console.error('Error activating SOS:', error);
    throw error;
  }
};

export const getSOSStatus = async (sosId) => {
  try {
    const response = await axios.get(`${API_BASE_URL}/sos/status/${sosId}`);
    return response.data;
  } catch (error) {
    console.error('Error getting SOS status:', error);
    throw error;
  }
};

export const sendChatMessage = async (userId, message, conversationId = null) => {
  try {
    const response = await axios.post(`${API_BASE_URL}/chat/message`, {
      user_id: userId,
      message: message,
      conversation_id: conversationId
    });
    return response.data;
  } catch (error) {
    console.error('Error sending message:', error);
    throw error;
  }
};

export const getPoliceStations = async (lat, lng) => {
  try {
    const response = await axios.get(
      `${API_BASE_URL}/resources/police-stations?lat=${lat}&lng=${lng}`
    );
    return response.data;
  } catch (error) {
    console.error('Error getting police stations:', error);
    throw error;
  }
};

export const getHospitals = async (lat, lng) => {
  try {
    const response = await axios.get(
      `${API_BASE_URL}/resources/hospitals?lat=${lat}&lng=${lng}`
    );
    return response.data;
  } catch (error) {
    console.error('Error getting hospitals:', error);
    throw error;
  }
};