import React, { useState, useEffect, useCallback, useRef } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged } from 'firebase/auth';
import { getFirestore, collection, query, orderBy, limit, getDocs, addDoc } from 'firebase/firestore';

// Define the Firebase config and app ID from the global variables
const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {};
const appId = typeof __app_id !== 'undefined' ? __app_id : 'default-app-id';

// Helper to convert base64 to ArrayBuffer (for potential future audio if needed)
function base64ToArrayBuffer(base64) {
    const binaryString = atob(base64);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
}

// Helper to convert PCM to WAV (for potential future audio if needed)
function pcmToWav(pcmData, sampleRate) {
    const numChannels = 1;
    const bytesPerSample = 2;
    const blockAlign = numChannels * bytesPerSample;
    const byteRate = sampleRate * blockAlign;

    const dataLength = pcmData.byteLength;
    const buffer = new ArrayBuffer(44 + dataLength);
    const view = new DataView(buffer);

    let offset = 0;

    function writeString(str) {
        for (let i = 0; i < str.length; i++) {
            view.setUint8(offset + i, str.charCodeAt(i));
        }
        offset += str.length;
    }

    function writeUint32(val) {
        view.setUint32(offset, val, true);
        offset += 4;
    }

    function writeUint16(val) {
        view.setUint16(offset, val, true);
        offset += 2;
    }

    // RIFF chunk
    writeString('RIFF');
    writeUint32(36 + dataLength);
    writeString('WAVE');

    // fmt chunk
    writeString('fmt ');
    writeUint32(16); // Chunk size
    writeUint16(1);  // Audio format (1 = PCM)
    writeUint16(numChannels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(16); // Bits per sample

    // data chunk
    writeString('data');
    writeUint32(dataLength);

    const pcmBytes = new Uint8Array(pcmData.buffer);
    for (let i = 0; i < pcmBytes.length; i++) {
        view.setUint8(offset + i, pcmBytes[i]);
    }

    return new Blob([view], { type: 'audio/wav' });
}


// Exercise data with muscle groups
const initialExercises = [
    { name: 'Press inclinado con mancuernas', muscleGroup: 'pecho', sets: [0, 0, 0] },
    { name: 'Remo con mancuernas en banco inclinado', muscleGroup: 'espalda', sets: [0, 0, 0] },
    { name: 'Curl de bíceps', muscleGroup: 'bíceps', sets: [0, 0, 0] },
    { name: 'Press militar', muscleGroup: 'hombros', sets: [0, 0, 0] },
    { name: 'Press francés', muscleGroup: 'tríceps', sets: [0, 0, 0] },
    { name: 'Vuelos con mancuernas', muscleGroup: 'hombros', sets: [0, 0, 0] },
];

// Mapping of muscle groups to minimalist emojis
const muscleGroupEmojis = {
    'pecho': '🏋️‍♂️', // Weightlifter for chest press
    'espalda': '🚣', // Rowing for back
    'bíceps': '💪', // Flexed biceps
    'hombros': '🤸', // Person doing cartwheel for shoulder mobility
    'tríceps': '💪', // Flexed biceps (general arm strength)
};

// Digital Timer component
const DigitalTimer = ({ initialMinutes = 2 }) => {
    const totalSeconds = initialMinutes * 60;
    const [secondsRemaining, setSecondsRemaining] = useState(totalSeconds);
    const [isRunning, setIsRunning] = useState(false);
    const intervalRef = useRef(null);

    const startTimer = () => {
        if (!isRunning && secondsRemaining > 0) {
            setIsRunning(true);
            intervalRef.current = setInterval(() => {
                setSecondsRemaining(prev => {
                    if (prev <= 1) {
                        clearInterval(intervalRef.current);
                        setIsRunning(false);
                        return 0;
                    }
                    return prev - 1;
                });
            }, 1000);
        }
    };

    const pauseTimer = () => {
        clearInterval(intervalRef.current);
        setIsRunning(false);
    };

    const resetTimer = () => {
        clearInterval(intervalRef.current);
        setIsRunning(false);
        setSecondsRemaining(totalSeconds);
    };

    useEffect(() => {
        return () => clearInterval(intervalRef.current);
    }, []);

    const minutes = Math.floor(secondsRemaining / 60);
    const seconds = secondsRemaining % 60;

    return (
        <div className="flex flex-col items-center justify-center mt-2 p-2 rounded-lg bg-neutral-900/50">
            <div className={`text-5xl font-mono ${secondsRemaining === 0 ? 'text-red-400' : 'text-emerald-400'}`}>
                {String(minutes).padStart(2, '0')}:{String(seconds).padStart(2, '0')}
            </div>
            <div className="flex space-x-3 mt-2">
                <button
                    onClick={isRunning ? pauseTimer : startTimer}
                    className="p-2 rounded-full bg-neutral-700 hover:bg-neutral-600 focus:outline-none focus:ring-2 focus:ring-blue-500 transition duration-150 ease-in-out"
                >
                    {isRunning ? (
                        <svg className="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clipRule="evenodd" />
                        </svg>
                    ) : (
                        <svg className="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clipRule="evenodd" />
                        </svg>
                    )}
                </button>
                <button
                    onClick={resetTimer}
                    className="p-2 rounded-full bg-neutral-700 hover:bg-neutral-600 focus:outline-none focus:ring-2 focus:ring-blue-500 transition duration-150 ease-in-out"
                >
                    <svg className="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M4 2a1 1 0 011-1h10a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V2zm3 6a1 1 0 011 1v6a1 1 0 11-2 0V9a1 1 0 011-1zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V9a1 1 0 00-1-1z" clipRule="evenodd" />
                    </svg>
                </button>
            </div>
        </div>
    );
};


// ExerciseCard component for individual exercise display and input
const ExerciseCard = ({ exercise, onRepsChange, historicalAverages }) => {
    const [reps, setReps] = useState(exercise.sets);
    const [isCompleted, setIsCompleted] = useState(false);

    useEffect(() => {
        // Reset reps when exercise changes (e.g., after saving a workout)
        setReps(initialExercises.find(ex => ex.name === exercise.name)?.sets || [0,0,0]);
        setIsCompleted(false); // Reset completion status on prop change
    }, [exercise.name]); // Depend on exercise.name to reset when different exercise props come in

    const handleRepChange = (setIndex, value) => {
        const newReps = [...reps];
        newReps[setIndex] = parseInt(value, 10) || 0;
        setReps(newReps);
        onRepsChange(exercise.name, newReps);

        // Always re-evaluate completion status
        const allSetsCurrentlyCompleted = newReps.every(r => r > 0);
        setIsCompleted(allSetsCurrentlyCompleted);
    };

    const totalReps = reps.reduce((sum, current) => sum + current, 0);

    return (
        <div className={`
            p-4 rounded-lg mb-4 backdrop-filter backdrop-blur-lg border border-neutral-700
            transition-colors duration-500 ease-in-out // Explicitly transition colors
            ${isCompleted ? 'bg-emerald-700/70' : 'bg-neutral-800/70'}
        `}>
            <h3 className="text-xl font-semibold text-white mb-2 flex items-center">
                <span className="mr-2 text-2xl">{muscleGroupEmojis[exercise.muscleGroup]}</span>
                {exercise.name}
            </h3>
            {reps.map((r, index) => (
                <div key={index} className="flex items-center justify-center mb-2">
                    <label className="text-neutral-300 mr-2 w-16 text-right">Serie {index + 1}:</label>
                    <input
                        type="number"
                        min="0"
                        value={r === 0 ? '' : r}
                        onChange={(e) => handleRepChange(index, e.target.value)}
                        className="w-20 p-2 rounded bg-neutral-900/70 text-white border border-neutral-600 focus:outline-none focus:ring-2 focus:ring-blue-500 text-center"
                    />
                    <span className="ml-4 text-neutral-400 text-sm font-bold w-12 text-center">
                        {historicalAverages?.series?.[index] !== undefined
                            ? historicalAverages.series[index].toFixed(1)
                            : 'N/A'}
                    </span>
                </div>
            ))}
            <DigitalTimer initialMinutes={2} /> {/* Digital Timer added here */}
            <div className="mt-4 pt-2 border-t border-neutral-700 text-center">
                <p className="text-white">
                    Total Repeticiones: <span className="font-bold">{totalReps}</span>
                </p>
                <p className="text-neutral-400 text-sm">
                    Promedio total (últ. 3 para {exercise.muscleGroup}):{' '}
                    {historicalAverages?.totalMuscleReps !== undefined
                        ? historicalAverages.totalMuscleReps.toFixed(1)
                        : 'N/A'}
                </p>
            </div>
        </div>
    );
};

// Main App component
function App() {
    const [workouts, setWorkouts] = useState(initialExercises);
    const [historicalData, setHistoricalData] = useState({});
    const [userId, setUserId] = useState(null);
    const [db, setDb] = useState(null);
    const [auth, setAuth] = useState(null);
    const [isAuthReady, setIsAuthReady] = useState(false);
    const [showModal, setShowModal] = useState(false);
    const [modalMessage, setModalMessage] = useState('');
    const [viewMode, setViewMode] = useState('currentRoutine'); // 'currentRoutine' or 'history'
    const [allWorkoutsHistory, setAllWorkoutsHistory] = useState([]);


    // Initialize Firebase and authenticate
    useEffect(() => {
        try {
            const app = initializeApp(firebaseConfig);
            const firestore = getFirestore(app);
            const authentication = getAuth(app);
            setDb(firestore);
            setAuth(authentication);

            const unsubscribe = onAuthStateChanged(authentication, async (user) => {
                if (user) {
                    setUserId(user.uid);
                } else {
                    // Sign in anonymously if no token is available
                    try {
                        const token = typeof __initial_auth_token !== 'undefined' ? __initial_auth_token : null;
                        if (token) {
                            await signInWithCustomToken(authentication, token);
                        } else {
                            await signInAnonymously(authentication);
                        }
                    } catch (error) {
                        console.error("Error signing in:", error);
                    }
                }
                setIsAuthReady(true);
            });
            return () => unsubscribe();
        } catch (error) {
            console.error("Error initializing Firebase:", error);
        }
    }, []);

    // Fetch historical data for averages
    const fetchHistoricalAverages = useCallback(async () => {
        if (!db || !userId || !isAuthReady) return;

        const allHistoricalWorkouts = {};
        const muscleGroupWorkouts = {};

        try {
            const workoutsRef = collection(db, `artifacts/${appId}/users/${userId}/workouts`);
            const q = query(workoutsRef, orderBy('date', 'desc'), limit(10)); // Fetch more to ensure we get last 3 for each exercise

            const querySnapshot = await getDocs(q);
            querySnapshot.forEach((doc) => {
                const data = doc.data();
                data.exercises.forEach(ex => {
                    if (!allHistoricalWorkouts[ex.name]) {
                        allHistoricalWorkouts[ex.name] = [];
                    }
                    allHistoricalWorkouts[ex.name].push(ex);

                    if (!muscleGroupWorkouts[ex.muscleGroup]) {
                        muscleGroupWorkouts[ex.muscleGroup] = [];
                    }
                    // Aggregate total reps for the muscle group from the workout's summary
                    const workoutMuscleTotal = data.totalMuscleReps?.[ex.muscleGroup] || ex.totalReps; // Fallback
                    muscleGroupWorkouts[ex.muscleGroup].push(workoutMuscleTotal);
                });
            });

            const calculatedAverages = {};
            initialExercises.forEach(ex => {
                const historicalExData = allHistoricalWorkouts[ex.name] || [];
                const lastThreeExWorkouts = historicalExData.slice(0, 3);

                if (lastThreeExWorkouts.length > 0) {
                    const seriesAverages = ex.sets.map((_, index) => {
                        const totalRepsForSeries = lastThreeExWorkouts.reduce((sum, workout) => sum + (workout.sets[index] || 0), 0);
                        return totalRepsForSeries / lastThreeExWorkouts.length;
                    });

                    // For muscle group average, we need to consider total reps across last 3 workouts for that muscle group
                    const historicalMuscleGroupTotals = muscleGroupWorkouts[ex.muscleGroup] || [];
                    const lastThreeMuscleGroupTotals = historicalMuscleGroupTotals.slice(0,3);

                    const totalMuscleRepsAverage = lastThreeMuscleGroupTotals.length > 0
                        ? lastThreeMuscleGroupTotals.reduce((sum, val) => sum + val, 0) / lastThreeMuscleGroupTotals.length
                        : 0;


                    calculatedAverages[ex.name] = {
                        series: seriesAverages,
                        totalMuscleReps: totalMuscleRepsAverage,
                    };
                }
            });
            setHistoricalData(calculatedAverages);
        } catch (error) {
            console.error("Error fetching historical data for averages:", error);
        }
    }, [db, userId, isAuthReady]);

    // Fetch all workouts for history view
    const fetchAllWorkoutsForHistory = useCallback(async () => {
        if (!db || !userId || !isAuthReady) return;

        try {
            const workoutsRef = collection(db, `artifacts/${appId}/users/${userId}/workouts`);
            const q = query(workoutsRef, orderBy('date', 'desc')); // No limit, fetch all for history
            const querySnapshot = await getDocs(q);
            const history = querySnapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));
            setAllWorkoutsHistory(history);
        } catch (error) {
            console.error("Error fetching all workouts for history:", error);
        }
    }, [db, userId, isAuthReady]);

    useEffect(() => {
        if (isAuthReady) {
            fetchHistoricalAverages();
            if (viewMode === 'history') {
                fetchAllWorkoutsForHistory();
            }
        }
    }, [isAuthReady, viewMode, fetchHistoricalAverages, fetchAllWorkoutsForHistory]);

    const handleRepsChange = useCallback((exerciseName, newReps) => {
        setWorkouts(prevWorkouts =>
            prevWorkouts.map(ex =>
                ex.name === exerciseName ? { ...ex, sets: newReps } : ex
            )
        );
    }, []);

    const saveWorkout = async () => {
        if (!db || !userId) {
            setModalMessage("Error: Firebase no está inicializado o el usuario no está autenticado.");
            setShowModal(true);
            return;
        }

        try {
            const workoutToSave = {
                date: new Date().toISOString(),
                exercises: workouts.map(ex => ({
                    name: ex.name,
                    muscleGroup: ex.muscleGroup,
                    sets: ex.sets,
                    totalReps: ex.sets.reduce((sum, current) => sum + current, 0),
                })),
                totalMuscleReps: initialExercises.reduce((acc, ex) => {
                    const currentEx = workouts.find(w => w.name === ex.name);
                    const totalReps = currentEx ? currentEx.sets.reduce((sum, r) => sum + r, 0) : 0;
                    acc[ex.muscleGroup] = (acc[ex.muscleGroup] || 0) + totalReps;
                    return acc;
                }, {}),
            };

            const workoutsCollectionRef = collection(db, `artifacts/${appId}/users/${userId}/workouts`);
            await addDoc(workoutsCollectionRef, workoutToSave);
            setModalMessage("¡Entrenamiento guardado exitosamente!");
            setShowModal(true);
            setWorkouts(initialExercises.map(ex => ({ ...ex, sets: [0, 0, 0] }))); // Reset inputs
            fetchHistoricalAverages(); // Re-fetch data to update averages
            if (viewMode === 'history') {
                fetchAllWorkoutsForHistory(); // Also update history if in that view
            }
        } catch (error) {
            console.error("Error saving workout:", error);
            setModalMessage(`Error al guardar el entrenamiento: ${error.message}`);
            setShowModal(true);
        }
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-black via-neutral-900 to-black p-4 font-inter text-white">
            <style>
                @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap');
            </style>
            <div className="max-w-xl mx-auto py-8">
                <h1 className="text-4xl font-bold text-center mb-6 text-blue-400">Rutina Martin</h1>

                <div className="flex justify-center space-x-4 mb-8">
                    <button
                        onClick={() => setViewMode('currentRoutine')}
                        className={`py-2 px-4 rounded-lg font-bold transition duration-300 ease-in-out ${
                            viewMode === 'currentRoutine'
                                ? 'bg-blue-600 text-white shadow-md'
                                : 'bg-neutral-700 text-neutral-300 hover:bg-neutral-600'
                        }`}
                    >
                        Rutina Actual
                    </button>
                    <button
                        onClick={() => setViewMode('history')}
                        className={`py-2 px-4 rounded-lg font-bold transition duration-300 ease-in-out ${
                            viewMode === 'history'
                                ? 'bg-blue-600 text-white shadow-md'
                                : 'bg-neutral-700 text-neutral-300 hover:bg-neutral-600'
                        }`}
                    >
                        Historial
                    </button>
                </div>

                {userId && (
                    <p className="text-center text-neutral-500 text-sm mb-4">
                        ID de Usuario: <span className="font-mono">{userId}</span>
                    </p>
                )}

                {viewMode === 'currentRoutine' ? (
                    <>
                        {workouts.map((exercise, index) => (
                            <ExerciseCard
                                key={exercise.name}
                                exercise={exercise}
                                onRepsChange={handleRepsChange}
                                historicalAverages={historicalData[exercise.name]}
                            />
                        ))}

                        <button
                            onClick={saveWorkout}
                            className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-4 rounded-lg mt-6 transition duration-300 ease-in-out transform hover:scale-105 shadow-lg"
                        >
                            Guardar Entrenamiento
                        </button>
                    </>
                ) : (
                    <div className="space-y-4">
                        {allWorkoutsHistory.length > 0 ? (
                            allWorkoutsHistory.map(workout => (
                                <div key={workout.id} className="bg-neutral-800/70 p-4 rounded-lg backdrop-filter backdrop-blur-lg border border-neutral-700">
                                    <p className="text-lg font-semibold text-blue-300 mb-2">
                                        Fecha: {new Date(workout.date).toLocaleDateString()} - {new Date(workout.date).toLocaleTimeString()}
                                    </p>
                                    <ul className="list-disc list-inside text-neutral-300">
                                        {workout.exercises.map((ex, exIndex) => (
                                            <li key={exIndex} className="mb-1">
                                                <span className="font-medium text-white">{ex.name}:</span>{' '}
                                                {ex.sets.map((s, sIndex) => `Serie ${sIndex + 1}: ${s} reps`).join(', ')}
                                                <span className="text-neutral-400"> (Total: {ex.totalReps} reps)</span>
                                            </li>
                                        ))}
                                    </ul>
                                </div>
                            ))
                        ) : (
                            <p className="text-center text-neutral-400">No hay entrenamientos guardados aún.</p>
                        )}
                    </div>
                )}
            </div>

            {/* Custom Modal for alerts */}
            {showModal && (
                <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center p-4 z-50">
                    <div className="bg-neutral-800/90 p-6 rounded-lg shadow-xl text-white max-w-sm w-full backdrop-filter backdrop-blur-lg border border-neutral-700">
                        <h3 className="text-xl font-bold mb-4 text-blue-400">Notificación</h3>
                        <p className="mb-6">{modalMessage}</p>
                        <button
                            onClick={() => setShowModal(false)}
                            className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded-lg transition duration-300 ease-in-out"
                        >
                            Cerrar
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}

export default App;
